## wikigram-tg
## Source is distributed under the AGPL v3.0
## https://www.gnu.org/licenses/agpl-3.0.html
##
## Contributions to the code are welcome.

require 'telegram/bot'
require 'mediawiki_api'
require 'json'

## CONFIGURATION START ##
token = 'INSERT_YOUR_BOT_TOKEN_HERE' # Telegram bot API token
api_ep = 'https://wikigram.it/api.php' # Mediawiki API endpoint
# api_ep = 'https://it.wikipedia.org/w/api.php' # Example: Wikipedia API endpoint
page_uri = "#{api_ep[0..-8]}/" # Base URL for pages
# page_uri = "#{api_ep[0..-10]}wiki/" # Example: URL pattern for Wikipedia
## CONFIGURATION END ##

mw = MediawikiApi::Client.new api_ep
bot_id = token.split(':').at(0).to_i

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    case message
    when Telegram::Bot::Types::InlineQuery
      puts "Processing inline query -- #{message.query}"

      if !message.query.empty? then
        query_search = mw.query(list: "search", srsearch: message.query)

        hash_search = []
        query_search.data["search"].each do |result|
          hash_search << result
        end

        results = []
        if query_search.data["searchinfo"]["totalhits"] == 0 then
          results << Telegram::Bot::Types::InlineQueryResultArticle.new(
            id: 1,
            title: "Nessun risultato presente.",
            input_message_content: Telegram::Bot::Types::InputTextMessageContent.new(message_text: "¯\\_(ツ)_/¯")
          )
        end

        counter = 1

        hash_search.each do |curres|
          cur_extract = mw.query(prop: "extracts", exchars: 300, exsectionformat: "plain", explaintext: "", redirects: "", exintro: true, titles: curres["title"])

          hash_extract = cur_extract.data["pages"]
          hash_extract.each do |id, page|
            norm_title = curres["title"].gsub(" ", "_")

            results << Telegram::Bot::Types::InlineQueryResultArticle.new(
              id: counter,
              title: curres["title"],
              input_message_content: Telegram::Bot::Types::InputTextMessageContent.new(message_text: "#{page["extract"]}"),
              description: "#{page["extract"][0..64]}...",
              reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
                inline_keyboard: [Telegram::Bot::Types::InlineKeyboardButton.new(
                  text: "Vedi l'articolo intero", url: "#{page_uri}#{norm_title}"
                )]
              )
            )
            counter = counter + 1
          end
        end

        bot.api.answer_inline_query(inline_query_id: message.id, results: results) rescue puts "Error in replying. Nothing too special."
      end

    when Telegram::Bot::Types::Message
      if message.chat.type == "private" then
        bot.api.send_message(chat_id: message.chat.id, text: "Questo bot risponde *solo* in modalità inline.\nThis bot replies *only* via inline queries.", parse_mode: "Markdown")
      end
    end
  end
end
