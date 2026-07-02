time=$(date +%s)
echo "Start time: $time"
sage Aradi.sage
new_time=$(date +%s)
elapsed_time=$((new_time - time))
echo "Elapsed time: $elapsed_time seconds"