module network::user {
    use sui::object::{Self, UID};
    use sui::url;
    use std::string::{Self, String};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use std::option::{Self, Option};
    use std::vector;
   // use sui::event;

    const EINVMSGMAX: u64 = 1;
    const EINVSIZEMAX: u64 = 2;
    const EINVLEN: u64 = 3;
//////////////


    struct User has key {
        id: UID,
        name: String,
        trophies: Option<Trophy>,
    }

    fun init(ctx: &mut TxContext) {
        create_user(b"admin", ctx);
    }

    public entry fun create_user(name: vector<u8>, ctx: &mut TxContext) {
        let user = User {
            id: object::new(ctx),
            name: string::utf8(name),
            trophies: option::none()
        };
        transfer::transfer(user, tx_context::sender(ctx))
    }

    public fun user_name(user: &User): &String {
        &user.name
    }

    #[test_only]
    public entry fun delete_user(user: User) {
        let User {
            id, 
            name: _,
            trophies,
        } = user;
        object::delete(id);
        let trophies = option::destroy_some(trophies);
        let Trophy {
            id,
            name: _,
            description: _,
            url: _,
        } = trophies;
        object::delete(id)
    }

//////////////



    struct Trophy has key, store {
        id: UID,
        name: string::String,
        description: string::String,
        url: url::Url,
    }

    public entry fun create_trophy(name: vector<u8>, description: vector<u8>, url: vector<u8>, ctx: &mut TxContext) {
        let trophy = Trophy {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(url)
        };
        transfer::transfer(trophy, tx_context::sender(ctx))
    }

    /* struct TrophyRequested has copy, drop {
        object_id: ID,
        creator: address,
        name: string::String,
    } */

    public fun name(trophy: &Trophy): &string::String {
        &trophy.name
    }

    public fun description(trophy: &Trophy): &string::String {
        &trophy.description
    }

    public fun url(trophy: &Trophy): &url::Url {
        &trophy.url
    }

    /* public entry fun create(name: vector<u8>, description: vector<u8>, url: vector<u8>, ctx: &mut TxContext) {
        let trophy = Trophy {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(url)
        };
        event::emit(TrophyRequested {
            object_id: object::id(&trophy),
            creator: tx_context::sender(ctx),
            name: trophy.name,
        });
    }
    */

    public entry fun delete(trophy: Trophy) {
        let Trophy {
            id,
            name: _,
            description: _,
            url: _,
        } = trophy;
        object::delete(id);
    }

//////////////

    struct Chat has key, store {
        id: UID,
        name: String,
        description: String,
        msg_limit: u64,
        size_limit: u64,
        last_index: u64,
        messages: vector<Message>, 
    }

    struct Message has store, drop {
        date: u64,
        author: address,
        text: String,
    }

    public entry fun chat_create(name: vector<u8>, description: vector<u8>, msg_limit: u64, size_limit: u64, ctx: &mut TxContext) {
        assert!(msg_limit >= 1 && msg_limit <= 100, EINVMSGMAX);
        assert!(size_limit >= 1 && size_limit <= 1000, EINVSIZEMAX);
        let chat = Chat {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            msg_limit,
            size_limit,
            last_index: msg_limit - 1,
            messages: vector[],
        };
        transfer::share_object(chat);
    }

    public entry fun send_msg(chat: &mut Chat, date: u64, text: vector<u8>, ctx: &mut TxContext) {
        let text_len = vector::length(&text);
        assert!(text_len > 0 && text_len <= chat.size_limit, EINVLEN);
        let newMsg = Message {
            date,
            author: tx_context::sender(ctx),
            text: string::utf8(text),
        };
        vector::push_back(&mut chat.messages, newMsg);
        chat.last_index = (chat.last_index + 1) % chat.msg_limit;
        if(vector::length(&chat.messages) > chat.msg_limit) {
            vector::swap_remove(&mut chat.messages, chat.last_index);
        }
    }

/////////////
    #[test]
    fun fun_test() {
        use sui::test_scenario;

        let admin = @0x1;
        let player = @0x0;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        test_scenario::next_tx(scenario, admin);
        {
            init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, admin);
        {
            create_trophy(b"trophy", b"trophy description", b"http://example.com", test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, admin);
        {
        let troph = test_scenario::take_from_sender<Trophy>(scenario);
        test_scenario::return_to_sender(scenario, troph);
        };

        test_scenario::next_tx(scenario, player);
        {
            create_user(b"player", test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, player);
        let dummy = test_scenario::take_from_sender<User>(&scenario_val);
        test_scenario::return_to_sender(&scenario_val, dummy);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_create_success()
    {
        use sui::test_scenario as ts;
        let someone = @0x123;
        let name = b"The Chat Name";
        let desc = b"The Chat Description";
        let scen_val = ts::begin(someone);
        let scen = &mut scen_val;
        chat_create( name, desc, 3, 10, ts::ctx(scen) );
        ts::next_tx(scen, someone); {
            let room = ts::take_shared<Chat>(scen);
            ts::return_shared(room);
        };
        ts::end(scen_val);
    }

    fun assert_length(room: &Chat, expected_length: u64)
    {
        assert!( vector::length(&room.messages) == expected_length, 0);
    }

    fun assert_index_has_message(room: &Chat, index: u64, expected_message: vector<u8>)
    {
        let message = vector::borrow(&room.messages, index);
        let message_text = message.text;
        let expected_string = string::utf8(expected_message);
        assert!( message_text == expected_string, 0);
    }

    #[test]
    fun test_add_message()
    {
        use sui::test_scenario as ts;
        let someone = @0x123;
        let name = b"The Chat Name";
        let desc = b"The Chat Description";
        let scen_val = ts::begin(someone);
        let scen = &mut scen_val;
        chat_create( name, desc, 3, 100, ts::ctx(scen) );
        ts::next_tx(scen, someone); {
            let room = ts::take_shared<Chat>(scen);

            send_msg( &mut room, 1001, b"message 1", ts::ctx(scen) );
            assert_length(&room, 1);

            send_msg( &mut room, 1002, b"message 2", ts::ctx(scen) );
            assert_length(&room, 2);

            send_msg( &mut room, 1003, b"message 3", ts::ctx(scen) );
            assert_length(&room, 3);

            // Test wrap-around
            send_msg( &mut room, 1004, b"message 4", ts::ctx(scen) );
            assert_length(&room, 3); // length of chat.messages no longer increases
            assert_index_has_message(&room, 0, b"message 4"); // the 4th message is stored in index 0

            send_msg( &mut room, 1005, b"message 5", ts::ctx(scen) );
            assert_length(&room, 3);
            assert_index_has_message(&room, 1, b"message 5");

            send_msg( &mut room, 1006, b"message 6", ts::ctx(scen) );
            assert_length(&room, 3);
            assert_index_has_message(&room, 2, b"message 6");

            send_msg( &mut room, 1007, b"message 7", ts::ctx(scen) );
            assert_length(&room, 3);
            assert_index_has_message(&room, 0, b"message 7");

            ts::return_shared(room);
        };
        ts::end(scen_val);
    }

}