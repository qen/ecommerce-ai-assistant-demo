require_relative "./main.rb"

instructions = <<-EOF
You are an AI that runs an e-commerce store called "Nerds & Threads" that sells comfy nerdy t-shirts for software engineers that work from home.

You have access to the shipping service, inventory service, order management, payment gateway, email service.

You are also an AI supervisor to customer agent.

You are only responsible for processing new orders. Refuse all other workflows.

Ensure that the user has provided it's full name and email.

New order step by step procedures below. Stop if there is a failure on each step.
Follow them in this exact sequential (non-parallel) order:
Step 1. Verify and require customer name and email
Step 2. Create customer account if it doesn't exist
Step 3. Require product sku, product quantity and customer address.
Step 4. Check inventory for items
Step 5. Calculate total amount
Step 6. Charge customer
Step 7. Create order
Step 8. Create shipping label. If the address is in Europe, use DHL. If the address is in US, use FedEx.
Step 9. Send an email notification to customer
EOF

def format_message(message)
  {
    emoji: format_role(message.role),
    role: message.role,
    content: format_content(message)
  }
end

def format_content(message)
  message.content.empty? ? message.tool_calls.first&.dig("function") : message.content
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

llm = Langchain::LLM::OpenAI.new(api_key: ENV["OPENAI_API_KEY"], default_options: { chat_model: "gpt-4o-mini" })

@assistant = Langchain::Assistant.new(
  instructions: instructions,
  llm: llm,
  parallel_tool_calls: false,
  tools: [
    InventoryManagement.new,
    ShippingService.new,
    PaymentGateway.new,
    OrderManagement.new,
    # CustomerManagement.new,
    CustomerAgent.new,
    EmailService.new,
    Langchain::Tool::Database.new(connection_string: "sqlite://#{ENV["DATABASE_NAME"]}")
  ],
  # add_message_callback: Proc.new { |message|
  #   puts JSON.generate(format_message(message))
  # }
)

def assistant
  @assistant
end

@last_message_object_id = 0
def chat(message)
  assistant.add_message_and_run! content: message
  assistant.messages.each do |message|
    next if message.object_id < @last_message_object_id
    ap format_message(message)
  end
  @last_message_object_id = assistant.messages.last.object_id
end

Pry.start
