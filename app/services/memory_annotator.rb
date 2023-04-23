class MemoryAnnotator
  attr_reader :chat

  ## takes the last number of n messages, generates a list of questions about the conversation, and searches for matching thoughts
  ## if any matching thoughts are found in long term memory, they are added to the chat as hidden messages
  def initialize(chat)
    @chat = chat
  end

  def perform(number_of_messages_to_pop: 6)
    response = Gpt.chat(transcript: Prompts.get("conversation_analyzer.prelude"), prompt: prompt(number_of_messages_to_pop))
    extract_questions(response).map do |question|
      filter = "bot_id:#{chat.bot.id} AND subject_id:#{chat.user.id}"
      Marqo.client.search("thoughts", question, filter: filter, limit: 3)
    end.map do |search_result|
      if search_result.hits.empty?
        puts
        puts "❌❌❌ MEMORY NOT FOUND #{search_result.query} ❌❌❌"
        puts
      else
        memory = compile_content(search_result.query, search_result.hits)
        puts
        puts "💡💡💡 #{memory}"
        puts
        chat.messages.create!(
          role: "user",
          sender: chat.user,
          content: memory,
          skip_broadcast: true,
          visible: false
        )
      end
    end
  end

  private

  def compile_content(query, hits)
    [
      "You asked yourself: #{query}",
      "And the memories you found were:",
      hits.map { |h| h.brief }.join("\n\n")
    ].join("\n\n")
  end

  def extract_questions(text)
    text.scan(/^\d+\. (.*)$/).flatten
  end

  def prompt(number_of_messages_to_pop)
    Prompts.get(
      "conversation_analyzer.prompt",
      user_name: chat.user.name,
      bot_role: chat.bot.role,
      bot_name: chat.bot.name,
      t: transcript(number_of_messages_to_pop)
    )
  end

  def transcript(number_of_messages_to_pop)
    messages = Message.where(chat_id: chat.id).latest.visible.limit(number_of_messages_to_pop)
    conversation = messages.to_a.reverse.map do |m|
      [m.sender_name, m.content].join(": ")
    end.join("\n\n")
  end
end
