/// NFT collection factory.
/// Mirrors `grndx::factory` (Aptos `aptos_token_objects`) re-implemented using
/// Sui's object model and `sui::display`.
module costrade::factory {

    use std::string::{Self, String};
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::url::{Self, Url};
    use sui::event;
    use sui::display;
    use sui::package;

    // ── One-time witness (for Display setup) ─────────────────────────────────────

    public struct FACTORY has drop {}

    // ── On-chain types ───────────────────────────────────────────────────────────

    /// A named NFT collection with a running token counter.
    public struct Collection has key, store {
        id:          UID,
        name:        String,
        description: String,
        uri:         Url,
        creator:     address,
        supply:      u64,
    }

    /// An individual NFT token.
    public struct Token has key, store {
        id:            UID,
        collection_id: ID,
        name:          String,
        description:   String,
        uri:           Url,
        royalty_bps:   u16,   // basis points, e.g. 500 = 5 %
    }

    // ── Events ────────────────────────────────────────────────────────────────────

    public struct CollectionCreated has copy, drop {
        collection_id: ID,
        creator:       address,
        name:          String,
    }

    public struct TokenMinted has copy, drop {
        token_id:      ID,
        collection_id: ID,
        name:          String,
        recipient:     address,
    }

    // ── Module initialiser ────────────────────────────────────────────────────────

    fun init(witness: FACTORY, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);

        let mut disp = display::new<Token>(&publisher, ctx);
        display::add(&mut disp, string::utf8(b"name"),        string::utf8(b"{name}"));
        display::add(&mut disp, string::utf8(b"description"), string::utf8(b"{description}"));
        display::add(&mut disp, string::utf8(b"image_url"),   string::utf8(b"{uri}"));
        display::update_version(&mut disp);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(disp, tx_context::sender(ctx));
    }

    // ── Public functions ──────────────────────────────────────────────────────────

    /// Create a new NFT collection (shared object).
    public entry fun create_collection(
        name:        vector<u8>,
        uri:         vector<u8>,
        description: vector<u8>,
        ctx:         &mut TxContext,
    ) {
        let creator = tx_context::sender(ctx);
        let col = Collection {
            id:          object::new(ctx),
            name:        string::utf8(name),
            description: string::utf8(description),
            uri:         url::new_unsafe_from_bytes(uri),
            creator,
            supply:      0,
        };
        event::emit(CollectionCreated {
            collection_id: object::id(&col),
            creator,
            name: col.name,
        });
        transfer::share_object(col);
    }

    /// Mint a token within a collection and send it to `recipient`.
    public entry fun mint_token(
        collection:  &mut Collection,
        name:        vector<u8>,
        description: vector<u8>,
        royalty_bps: u16,
        uri:         vector<u8>,
        recipient:   address,
        ctx:         &mut TxContext,
    ) {
        collection.supply = collection.supply + 1;
        let col_id = object::id(collection);
        let token = Token {
            id:            object::new(ctx),
            collection_id: col_id,
            name:          string::utf8(name),
            description:   string::utf8(description),
            uri:           url::new_unsafe_from_bytes(uri),
            royalty_bps,
        };
        event::emit(TokenMinted {
            token_id:      object::id(&token),
            collection_id: col_id,
            name:          token.name,
            recipient,
        });
        transfer::public_transfer(token, recipient);
    }

    // ── Accessors ─────────────────────────────────────────────────────────────────

    public fun collection_supply(col: &Collection): u64     { col.supply }
    public fun collection_name(col: &Collection): String    { col.name }
    public fun collection_creator(col: &Collection): address { col.creator }
    public fun token_name(tok: &Token): String              { tok.name }
    public fun token_collection(tok: &Token): ID            { tok.collection_id }
}
