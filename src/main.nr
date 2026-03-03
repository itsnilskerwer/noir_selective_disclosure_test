use dep::std;
use dep::poseidon::poseidon::bn254;

global N: u32 = 4;  // max number of dataset quads used in proof
global K: u32 = 3;  // number of disclosed terms in this example

// Example disclosed triples/tuples:

// Quad 0: (s0_disclosed, p0_disclosed, o0_val_hidden, o0_suf_hidden, g0_hidden_),
// Quad 1: (s1_hidden, p1_disclosed, o1_val_hidden, o1_suf_hidden, g1_hidden),

// ==========================================
// HASH / MERKLE HELPERS
// ==========================================

fn merkle_step(left: Field, right: Field) -> Field {
    bn254::hash_2([left, right])
}

fn hash_leaf(q: [Field; 5]) -> Field {
    bn254::hash_5(q)
}

// For an exemplary dataset of size N = 4 we hardcode a 2-level binary tree
// In production, standard convention for building binary merkle trees should be used
fn merkle_root_from_leaves(leaves: [Field; N]) -> Field {
    // Level 1
    let h01 = merkle_step(leaves[0], leaves[1]);
    let h23 = merkle_step(leaves[2], leaves[3]);
    // Level 2 (root)
    let root = merkle_step(h01, h23);
    root
}

// ==========================================
// MAIN CIRCUIT
// ==========================================

fn main(
    // Issuer PUBLIC KEY
    pub_key_x: pub [u8; 32],
    pub_key_y: pub [u8; 32],

    // private RDF terms
    // Canonical, lexicographically sorted 5-tuples (contains all dataset terms)
    sorted_quads: [[Field; 5]; N],

    // public RDF terms
    disclosed_terms:pub [Field; K],

    // For each disclosed term k: [quad_index, pos_index]
    //   quad_index: points to 5-tuple in sorted_quads[0..N)
    //   pos_index:  which position in [s, p, o_val, o_suf, g]
    disclosed_positions: pub [[Field; 2]; K],

    // Signed Merkle root of the entire, sorted dataset
    root: Field,

    // ECDSA signature over root bytes
    signature: [u8; 64],

) {

    // 1. Verify ECDSA signature on root
    let root_bytes: [u8; 32] = root.to_be_bytes();

    let valid_signature = std::ecdsa_secp256k1::verify_signature(
        pub_key_x,
        pub_key_y,
        signature,
        root_bytes,
    );
    assert(valid_signature);

    // 2. Positional integrity: disclosed term hashes are at the claimed positions within a tuple, and within the sorted dataset
    for k in 0..K {

        let q_idx_f = disclosed_positions[k][0];
        let p_idx_f = disclosed_positions[k][1];

        // Field to u32
        let q_idx = q_idx_f as u32;
        let p_idx = p_idx_f as u32;

        // Bounds check
        assert(q_idx < N);
        assert(p_idx < 5);

        let quad_idx = q_idx as u32;
        let pos_idx = p_idx as u32;

        // Enforce term's position at (quad_idx, pos_idx)
        // equals the term hash in the sorted dataset
        assert(
            sorted_quads[quad_idx][pos_idx] == disclosed_terms[k]
        );
    }

    // 3. Recompute Merkle root from all leaves
    let mut leaves: [Field; N] = [0; N];

    for i in 0..N {
        leaves[i] = hash_leaf(sorted_quads[i]);
    }

    let computed_root = merkle_root_from_leaves(leaves);
    assert(computed_root == root);

}
