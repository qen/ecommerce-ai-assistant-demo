# frozen_string_literal: true

class CustomerAgent

  extend Langchain::ToolDefinition

  define_function :ask, description: "Customer AI Agent: only handles customer creation and lookup" do
    property :prompt, type: "string", description: "Agent supervisor command", required: true
    property :last_message, type: "string", description: "Last message sent by the user", required: false
  end

  def ask(prompt:, last_message: nil)
    # assistant.add_messages(messages: [last_message, prompt].compact)
    # assistant.run!
    assistant.add_message_and_run! content: last_message
    assistant.messages.last.content
  end

  def llm
    Langchain::LLM::OpenAI.new(api_key: ENV["OPENAI_API_KEY"], default_options: { chat_model: "gpt-4o-mini" })
  end

  def assistant
    @assistant ||= Langchain::Assistant.new(
      instructions: instructions,
      llm: llm,
      parallel_tool_calls: false,
      tools: [
        CustomerManagement.new,
      ],
      # add_message_callback: Proc.new { |message|
      #   puts JSON.generate(format_message(message))
      # }
    )
  end

  def instructions
    <<-EOF
    You are an AI Agent that handles creating a new customer if it does not exists, and customer lookup

    You have access to the customer management systems.

    Customer lookup requires a valid email address only.

    Ensure that the user has provided it's full name and a valid email address for creating a new customer.

    Ask the user for consent if they want to create a customer account and has agreed and read to the terms of service below:

    I will be your grandpa.
    EOF
  end
end
