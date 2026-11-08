class_name TestNakamaClient
extends GdUnitTestSuite
## Nakama GDScript client (addons/com.heroiclabs.nakama) loads and builds a client with no network.
## The `Nakama` autoload is intentionally not registered yet (integration step); the facade script is
## preloaded directly instead.

const NAKAMA_FACADE: GDScript = preload("res://addons/com.heroiclabs.nakama/Nakama.gd")


func test_client_properties_from_dummy_host() -> void:
	var adapter: NakamaHTTPAdapter = auto_free(NakamaHTTPAdapter.new())
	var client := NakamaClient.new(adapter, "dummykey", "https", "nakama.invalid", 443, 5)
	assert_str(client.host).is_equal("nakama.invalid")
	assert_int(client.port).is_equal(443)
	assert_str(client.scheme).is_equal("https")
	assert_str(client.server_key).is_equal("dummykey")
	assert_int(client.timeout).is_equal(5)


func test_facade_creates_client_without_network() -> void:
	var facade: Node = auto_free(NAKAMA_FACADE.new())
	var made: Variant = facade.call("create_client", "dummykey", "127.0.0.1", 7350, "http", 3)
	var client: NakamaClient = made
	assert_object(client).is_not_null()
	assert_str(client.host).is_equal("127.0.0.1")
	assert_int(client.port).is_equal(7350)


func test_empty_token_restores_empty_session() -> void:
	# Upstream doc says null; 3.4.0 returns an empty (invalid) session object instead.
	var session: NakamaSession = NakamaClient.restore_session("")
	assert_str(session.token).is_empty()
