# frozen_string_literal: true

class User < ApplicationRecord
  include PgSearch::Model
  multisearchable against: %i[first_name last_name username note]
  has_many :replies, dependent: :destroy
  has_many :requests, through: :replies
  default_scope { order(:first_name, :last_name) }
  validates :email, presence: false, 'valid_email_2/email': true

  def self.upsert_via_telegram(message)
    from, chat = message.values_at('from', 'chat')
    telegram_chat_id = chat['id']
    telegram_id, username, first_name, last_name = from.values_at('id', 'username', 'first_name', 'last_name')
    user = User.find_by(telegram_id: telegram_id)
    if user
      user.username = username
      user.telegram_chat_id = telegram_chat_id
      user.save!
    else
      user = User.create!(
        telegram_id: telegram_id,
        telegram_chat_id: telegram_chat_id,
        username: username,
        first_name: first_name,
        last_name: last_name
      )
    end
    user
  end

  def reply_via_telegram(message)
    user = self
    request = Request.active_request or return nil
    media_group_id = message['media_group_id']
    text = message['text'] || message['caption']
    ActiveRecord::Base.transaction do
      reply = Reply.find_by(telegram_media_group_id: media_group_id) if media_group_id
      reply ||= Reply.create!(text: text, user: user, request: request, telegram_media_group_id: media_group_id)
      reply.photos << Photo.create(telegram_message: message, reply: reply) if message['photo']
    end
  end

  def reply_via_mail(mail)
    user = self
    request = Request.active_request or return nil
    Reply.create!(request: request, text: mail.decoded, user: user)
  end

  def name
    "#{first_name} #{last_name}"
  end

  def name=(full_name)
    first_name, last_name = full_name.split(' ')
    self.first_name = first_name
    self.last_name = last_name
  end

  def replies_for_request(request)
    replies.where(request_id: request)
  end

  def channels
    { email: email?, telegram: telegram? }.select { |_k, v| v }.keys
  end

  def telegram?
    telegram_id.present? && telegram_chat_id.present?
  end

  def email?
    email.present?
  end
end
