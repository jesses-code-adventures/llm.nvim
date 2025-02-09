.PHONY: groq-models

PROJECT_ROOT:=$(shell git rev-parse --show-toplevel)
ENV:=$(PROJECT_ROOT)/.env

-include $(ENV)

keys:
	@echo "Anthropic: $(ANTHROPIC_API_KEY)"
	@echo "Deepseek: $(DEEPSEEK_API_KEY)"
	@echo "Groq: $(GROQ_API_KEY)"
	@echo "Google: $(GOOGLE_API_KEY)"
	@echo "Openai: $(OPENAI_API_KEY)"

groq-models:
	@curl -X GET "https://api.groq.com/openai/v1/models" --no-progress-meter \
		 -H "Authorization: Bearer $(GROQ_API_KEY)" \
		 -H "Content-Type: application/json" | jq -r '.data | .[] | .id' | sort

anthropic-models:
	@curl -X GET "https://api.anthropic.com/v1/models?limit=1000" --no-progress-meter \
		 -H "x-api-key: $(ANTHROPIC_API_KEY)" \
		 -H "anthropic-version: 2023-06-01" \
		 -H "Content-Type: application/json" | jq -r '.data | .[] | .id' | sort

test-openai:
	curl -XPOST -H 'Authorization: Bearer $(OPENAI_API_KEY)' -H "Content-type: application/json" -d '{ \
	  "model": "gpt-3.5-turbo", \
	  "messages": [ \
		{ \
		  "role": "system", \
		  "content": "You are a helpful assistant." \
		}, \
		{ \
		  "role": "user", \
		  "content": "Who won the world series in 2020?" \
		}, \
		{ \
		  "role": "assistant", \
		  "content": "The Los Angeles Dodgers won the World Series in 2020." \
		}, \
		{ \
		  "role": "user", \
		  "content": "Where was it played?" \
		} \
	  ] \
	}' 'https://api.openai.com/v1/chat/completions'
