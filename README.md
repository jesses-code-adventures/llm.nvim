<img src="https://github.com/yacineMTB/dingllm.nvim/assets/10282244/d03ef83d-a5ee-4ddb-928f-742172f3c80c" alt="wordart (6)" style="width:200px;height:100px;">

### dingllm.nvim

This is my fork of yacine's [dingllm.nvim](https://github.com/yacineMTB/dingllm.nvim), which adds a couple of features and takes a different approach to configuration.

### Credits

This extension woudln't exist if it weren't for https://github.com/melbaldove/llm.nvim

Yacine diff'd on a fork of it until it was basically a rewrite. Thanks @melbaldove!

I then did the same to [yacine's plugin](https://github.com/yacineMTB/dingllm.nvim), and the cycle continues.

### lazy config

Add your API keys to your env (export it in zshrc or bashrc).

The following api key names are used for the supported providers.

```txt
OPENAI_API_KEY
ANTHROPIC_API_KEY
GEMINI_API_KEY
DEEPSEEK_API_KEY
```

````lua
return {
    {
        "jesses-code-adventurs/dingllm.nvim",
        dependencies = { 'nvim-lua/plenary.nvim' },
        opts = {
            replace_prompt =
            'You should replace the code that you are sent, only following the comments. Do not talk at all. Only output valid code. Do not provide any backticks that surround the code. Never ever output backticks like this ```. Any comment that is asking you for something should be removed after you satisfy them. Other comments should left alone. Do not output backticks. Include a newline ("\n") at the beginning of any answer..',
            help_prompt =
            'You are a helpful assistant. What I have sent are my notes so far. You are very curt, yet helpful.'
        },
        keys = {
            -- note: i prefer use these directly in the file i'm editing
            { '<leader>lr', function() require('dingllm').replace() end, { desc = 'llm replace codeblock' }, { mode = "n" } },
            { '<leader>lr', function() require('dingllm').replace() end, { desc = 'llm replace codeblock' }, { mode = "v" } },
            -- note: i prefer these when writing in markdown mode
            { '<leader>lh', function() require('dingllm').help() end, { desc = 'llm helpful response' }, { mode = "n" } },
            { '<leader>lh', function() require('dingllm').help() end, { desc = 'llm helpful response' }, { mode = "n" } },
            -- use .models() to select your model, and toggle the reasoning window display
            { '<leader>lm', function() require('dingllm').models() end, { desc = 'llm model selector' } },
        },
    }
}
````
