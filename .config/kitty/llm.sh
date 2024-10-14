#!/bin/zsh

input="$(cat)"

echo $input
# needed because we are running inside a script, otherwise
# read will not wait for the user input
exec < /dev/tty

# ------------------------
# Chat loop custom implementation
# ------------------------
read_input() {
    if [ -n "$ZSH_VERSION" ]; then
        echo -n "$1"
        read -r REPLY
    else
        read -p "$1" -r REPLY
    fi
}

prompt="I'll give you the output of my last command in zsh. Answer the question you'll be given concisely and precisely. Do not repeat your system instruction.

# COMMAND OUTPUT
\`\`\`
$input
\`\`\`"

echo "Ask a question about the last command output (C-c to quit):\n"

first_question=true

while true; do
    read_input "> "
    question=$REPLY

    output=$(echo $question | llm -m gemini-pro -s "$prompt" | tee /dev/tty )

    if [ "$first_question" = true ]; then
        prompt="${prompt}\n\n# CONVERSATION HISTORY:\n\nUSER: ${question}\n\nASSISTANT: ${output}"
        first_question=false
    else
        prompt="${prompt}\n\n USER:${question}\nASSISTANT:${output}"
    fi
done

# ------------------------
# In alternative, you can try with the integrated "chat" feature.
# ------------------------
# llm chat -m gemini-1.5-flash-latest -s "$prompt"
