echo $1
if [[ "$1" =~ $2 ]]; then
  echo "match"
else
  echo "no match"
fi
