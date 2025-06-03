#!/bin/bash
# send_telegram.sh

send_telegram_messages() {
    # Очищаем входные параметры от кавычек
    local token=$(trim_quotes "$1")
    local chat_ids_param=$(trim_quotes "$2")
    local total_parts=$(trim_quotes "$3")

    if [ -z "$token" ] || [ -z "$chat_ids_param" ] || [ -z "$total_parts" ]; then
        echo "Error: Missing required parameters" >&2
        echo "Usage: send_telegram_messages token chat_ids total_parts" >&2
        echo "chat_ids format: 'chat_id1[,thread_id1]\nchat_id2[,thread_id2]'" >&2
        return 1
    fi

    # Разбиваем chat_ids по переносам строк
    IFS=$'\n' read -d '' -r -a chat_lines <<< "$chat_ids_param"
    
    # Обрабатываем каждую строку с chat_id
    for chat_line in "${chat_lines[@]}"; do
        # Пропускаем пустые строки
        [ -z "$chat_line" ] && continue
        
        # Разбиваем строку по запятой
        IFS=',' read -r chat_id message_thread_id <<< "$chat_line"
        
        # Убираем лишние пробелы
        chat_id=$(echo "$chat_id" | xargs)
        message_thread_id=$(echo "$message_thread_id" | xargs)
        
        echo "Processing chat_id: $chat_id"
        if [ -n "$message_thread_id" ]; then
            echo "Using message_thread_id: $message_thread_id"
        fi
        
        # Отправляем все части сообщения для текущего chat_id
        for i in $(seq 0 $((total_parts - 1))); do
            if [ ! -f "./tmp_messages/part_${i}.txt" ]; then
                echo "Error: Message file part_${i}.txt not found" >&2
                continue
            fi

            MESSAGE=$(cat "./tmp_messages/part_${i}.txt")
            echo "Sending part $i to chat $chat_id"
            
            # Формируем параметры для curl
            curl_params=(
                -s -X POST "https://api.telegram.org/bot${token}/sendMessage"
                -d "chat_id=${chat_id}"
                -d "parse_mode=HTML"
                -d "text=${MESSAGE}"
                -d "disable_web_page_preview=true"
            )
            
            # Добавляем message_thread_id если он есть
            if [ -n "$message_thread_id" ]; then
                curl_params+=(-d "message_thread_id=${message_thread_id}")
            fi
            
            RESPONSE=$(curl "${curl_params[@]}")

            if ! echo "$RESPONSE" | grep -q '"ok":true'; then
                echo "Error sending message part $i to chat $chat_id: $RESPONSE" >&2
            else
                echo "Successfully sent part $i to chat $chat_id"
            fi
            
            # Добавляем небольшую задержку между отправками сообщений
            sleep 1
        done
        
        echo "Finished processing chat_id: $chat_id"
        echo "---"
    done
}