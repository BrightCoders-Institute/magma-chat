class ChatAnalysisJob < ApplicationJob
  queue_as :default

  def perform(chat)
    prompt = Prompts.get("chats.analyze", lang: chat.user.settings.preferred_language)
    prompt_tokens = TikToken.count(prompt)
    Gpt.chat(prompt: prompt, max_tokens: 200, transcript: chat.messages_for_gpt(prompt_tokens + 200)).then do |json|
      puts
      puts "🔥🔥🔥 #{json} 🔥🔥🔥"
      puts
      JSON.parse(json.match(/.*?(\{.*\})/m)[1], symbolize_names: true).then do |data|
        Rails.logger.info(data)
        chat.title = data[:title] if data[:title]
        chat.analysis = chat.analysis.merge(data)
        chat.save!
      end
    end
  end
end
