import redis

# Replace with the Redis endpoint from Terraform output
REDIS_ENDPOINT = "redis-demo-cluster.ukjhop.0001.apse1.cache.amazonaws.com"
REDIS_PORT = 6379

def connect_to_redis():
    try:
        # Connect to the Redis cluster
        r = redis.Redis(host=REDIS_ENDPOINT, port=REDIS_PORT, db=0)
        print("Connected to Redis!")
        return r
    except Exception as e:
        print(f"Failed to connect to Redis: {e}")
        return None

def store_key_value(r, key, value):
    if r is None:
        print("Redis client is not connected. Cannot store key-value pair.")
        return

    try:
        # Store a key-value pair in Redis
        r.set(key, value)
        print(f"Stored key '{key}' with value '{value}' in Redis.")
    except Exception as e:
        print(f"Failed to store key-value pair: {e}")

def retrieve_value(r, key):
    if r is None:
        print("Redis client is not connected. Cannot retrieve value.")
        return

    try:
        # Retrieve the value for a given key
        value = r.get(key)
        if value:
            print(f"Retrieved key '{key}' with value '{value.decode('utf-8')}' from Redis.")
        else:
            print(f"Key '{key}' not found in Redis.")
    except Exception as e:
        print(f"Failed to retrieve value: {e}")

if __name__ == "__main__":
    # Connect to Redis
    redis_client = connect_to_redis()

    if redis_client:
        # Store a key-value pair
        store_key_value(redis_client, "demo_key", "Hello, ElastiCache!")

        # Retrieve the value
        retrieve_value(redis_client, "demo_key")
    else:
        print("Redis client is not connected. Exiting.")