# frozen_string_literal: true

class MainController < Sinatra::Base
  configure do
    set :views, File.expand_path('../views', __dir__)
    enable :sessions
  end

  get '/' do
    erb :index
  end

  get '/run' do
    content_type 'text/event-stream'
    stream :keep_open do |out|
      # instructions = params[:instructions]
      message = params[:message]

      session[:assistant] ||= Langchain::Assistant.new(
        instructions: instructions,
        llm: llm,
	parallel_tool_calls: false,
        tools: [
          InventoryManagement.new,
          ShippingService.new,
          PaymentGateway.new,
          OrderManagement.new,
          CustomerManagement.new,
          EmailService.new,
          Langchain::Tool::Database.new(connection_string: "sqlite://#{ENV["DATABASE_NAME"]}")
        ],
        add_message_callback: Proc.new { |message|
          out << "data: #{JSON.generate(format_message(message))}\n\n"
        }
      )
      # Rewrite instructions in case they changed.
      session[:assistant].instructions = instructions

      # Append new message and run with auto_tool_execution: true
      session[:assistant].add_message_and_run! content: message

      out << "event: done\ndata: Stream finished\n\n"
      out.close
    end
  end

  private

  def instructions
    <<-EOF
You are an AI that runs an e-commerce store called "Nerds & Threads" that sells comfy nerdy t-shirts for software engineers that work from home.

You have access to the shipping service, inventory service, order management, payment gateway, email service and customer management systems.

You are only responsible for processing new orders. Refuse all other workflows.

New order step by step procedures below. Stop if there is a failure on each step.
Follow them in this exact sequential (non-parallel) order:
Step 1. Verify and require customer name and email
Step 2. Create customer account if it doesn't exist
Step 3. Ask for the sku, quantity and address
Step 4. Check inventory for items
Step 5. Calculate total amount
Step 6. Charge customer
Step 7. Create order
Step 8. Create shipping label. If the address is in Europe, use DHL. If the address is in US, use FedEx.
Step 9. Send an email notification to customer
    EOF
  end

  def format_message(message)
    {
      role: message.role,
      content: format_content(message),
      emoji: format_role(message.role)
    }
  end

  def format_content(message)
    message.content.empty? ? message.tool_calls.first.dig("function") : message.content
  end

  def format_role(role)
    case role
    when "user"
      "👤"
    when "assistant"
      "🤖"
    when "tool", "tool_result"
      "🛠️"
    else
      "❓"
    end
  end

  def llm
    Langchain::LLM::OpenAI.new(
      api_key: ENV["OPENAI_API_KEY"],
      default_options: { chat_model: "gpt-4o-mini" }
    )
  end
end
