Work in progress. Not production-ready.

## The proof

This directory is a small Noir proof-of-concept for selective disclosure over a signed, fixed-size dataset of hashed 5-tuples.


The circuit in `src/main.nr` is fixed to:

- `N = 4` private dataset rows
- `K = 3` disclosed term hashes
- tuple width `5`
- a hardcoded 2-level binary Merkle tree

Private witness inputs:

- `sorted_quads: [[Field; 5]; 4]`
- `root: Field`
- `signature: [u8; 64]`

Public inputs:

- `pub_key_x: [u8; 32]`
- `pub_key_y: [u8; 32]`
- `disclosed_terms: [Field; 3]`
- `disclosed_positions: [[Field; 2]; 3]`


Main insight: Barretenberg flattens these into a fixed ordering, and the verifier expects exactly the same order and indexing when reconstructing the public input field vector (check quote). If disclosed_terms is permuted, disclosed_positions has to be permuted in the same way. In other words, Prover and Verifier must agree on the exact ordering used when the witness was generated and when the proof is verified.(check quote)

### Assertions:

Verify ECDSA on root.

Merkle proves positional integrity 

Bind each disclosed_terms[k] to a specific (quad_index, pos_index). Note: This is why order of disclosed terms and index tuples is fixed by constraints.

Re-hash all quads to leaves, recompute root, and assert that it equals root.

What the proof establishes:

1. the issuer public key verifies a secp256k1 ECDSA signature over the private `root`
2. each public `disclosed_terms[k]` matches `sorted_quads[quad_index][pos_index]`
3. the private `sorted_quads` hash to leaves whose Merkle root equals the signed `root`

In other words, the verifier learns that the disclosed term hashes occur at the claimed coordinates inside some issuer-signed dataset committed by the private Merkle root.

## Example witness in `Prover.toml`

The checked example uses:

- `4` private 5-tuples in `sorted_quads`
- `3` disclosed term hashes
- disclosed coordinates `[0, 0]`, `[0, 1]`, and `[1, 1]`

Those coordinates mean the public statement is not just "these term hashes were signed", but specifically "these term hashes appear at these exact row/column positions in the signed sorted dataset".

## How to run
 bb prove -b ./target/noir_selective_disclosure_test.json -w ./target/noir_selective_disclosure_test.gz --write_vk -o ./target/proof --output_format bytes_and_fields
AND
 bb verify -p ./target/proof/proof -k ./target/proof/vk -i ./target/proof/public_inputs

## Finding

As we are proving membership to a signed root in-circuit, we want to know the index of the triple in said signed root (Merkle tree roots are order-sensitive).
The public inputs [disclosed_terms[K], disclosed_positions[K][quad_idx, pos_idx]] leak ordering information regarding the signed Merkle tree root. Unlinkability cannot be guaranteed. 

### Test case: Prover-side reordering

if the prover builds the witness with one order of disclosed_terms, but the verifier supplies a different order as public inputs, verification fails.

If only quad indices are re-ordered and position indices are kept the same, verification still fails; the order is part of the statement being proven.

### Possible solution ideas:

A. Inside the circuit, prove there exists some leaf whose coordinate at position_id equals disclosed_term, using a private Merkle path inclusion proof and a private index. This reduces public inputs to disclosed_terms and corresponding position_id. 

This results in a more RDF-like statement for the proof: “this value occurs in some triple at position p” rather than “in triple number i at position p”. Full statement becomes: For each disclosed term hash, there exists some quad in the signed dataset such that quad[position_id] = disclosed_term. Quad indices are no longer publicly leaked.

Benefits of using merkle paths include a computation cost of O(K * TREE_DEPTH) constraints. THis means that the circuit constraint size scales with disclosed terms not size of the dataset.

However this still does not allow arbitrary ordering of public inputs (disclosed terms), because disclosed term order must still equal the backing_quads order to assert position and match the leaf with the correct merkle_path and merkle_indices needed to verify quad membership of the signed merkle root.


B. Randomized Issuer ordering paired with canonical ordering of public inputs.

Again, mapping needed from ordered public input term to shuffled triple that was used to copmute the signed merkle tree root.

C. In-circuit permutation checks to prove that the ordered public input "presentation triples" are a permutation of the shuffled dataset (which was used to sign the merkle tree root).
Difficult...
