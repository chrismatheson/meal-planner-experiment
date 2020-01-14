for i in {1..100}
do
	curl https://www.themealdb.com/api/json/v1/1/random.php > raw-data/$(date +%s)-$RANDOM.json
done
