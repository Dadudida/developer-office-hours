require 'stripe'
require 'sinatra'
require 'dotenv'
require 'sinatra/reloader' if development?

# Replace if using a different env file or config
Dotenv.load
Stripe.api_key = ENV['STRIPE_SECRET_KEY']

set :static, true
set :public_folder, File.join(File.dirname(__FILE__), ENV['STATIC_DIR'])
set :views, File.join(File.dirname(__FILE__), ENV['STATIC_DIR'])
set :port, 4242

get '/' do
  erb :index
end

post '/sepa' do
  email = params[:email]
  name = params[:name]
  amount = 1200

  customer = Stripe::Customer.create({
    email: email,
    name: name
  })

  payment_intent = Stripe::PaymentIntent.create({
    amount: amount,
    currency: 'eur',
    customer: customer.id,
    payment_method_types: ['sepa_debit'],
  })

  locals = {
    amount: amount,
    name: customer.name,
    email: customer.email,
    client_secret_id: payment_intent.client_secret,
  }

  erb :sepa, locals: locals
end

post '/webhook' do
  # You can use webhooks to receive information about asynchronous payment events.
  # For more about our webhook events check out https://stripe.com/docs/webhooks.
  webhook_secret = ENV['STRIPE_WEBHOOK_SECRET']
  payload = request.body.read
  if !webhook_secret.empty?
    # Retrieve the event by verifying the signature using the raw body and secret if webhook signing is configured.
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    event = nil

    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, webhook_secret
      )
    rescue JSON::ParserError => e
      # Invalid payload
      status 400
      return
    rescue Stripe::SignatureVerificationError => e
      # Invalid signature
      puts "⚠️  Webhook signature verification failed."
      status 400
      return
    end
  else
    data = JSON.parse(payload, symbolize_names: true)
    event = Stripe::Event.construct_from(data)
  end
  # Get the type of webhook event sent - used to check the status of PaymentIntents.
  event_type = event['type']
  data = event['data']
  data_object = data['object']

  case event_type

  when 'payment_intent.created'
    puts "🔔  payment intent created"
  when 'payment_intent.processing'
    puts "🔔  payment intent is processing"
  when 'payment_intent.succeeded'
    puts "🔔  payment intent succeeded"
  when 'payment_intent.payment_failed'
    puts "🔔  payment intent failed"
  end

  content_type 'application/json'
  {
    status: 'success'
  }.to_json
end
