  while true; do
    response=$(curl -s http://127.0.0.1:8080/ready)
    if [ "$response" = "ok" ]; then
      echo "Zebra is ready!"
      break
    fi
    echo "Not ready yet: $response"
    sleep 5
  done