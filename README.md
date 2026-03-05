
## The proof

In-circuit:
```noir
issuer_pubkey_x: pub [u8; 32],
    issuer_pubkey_y: pub [u8; 32],
    disclosed_terms: pub [Field; K],
    disclosed_positions: pub [[Field; 2]; K]
```

Note: Barretenberg flattens these into a fixed ordering, and the verifier expects exactly the same order and indexing when reconstructing the public input field vector (check quote). If disclosed_terms is permuted, disclosed_positions has to be permuted in the same way. In other words, Prover and Verifier must agree on the exact ordering used when the witness was generated and when the proof is verified.(check quote)

```noir
root: Field,
    signature: [u8; 64],
    sorted_quads: [[Field; 5]; N]
```

### Assertions:

Verify ECDSA on root.

Merkle proves positional integrity 

Bind each disclosed_terms[k] to a specific (quad_index, pos_index). Note: This is why order of disclosed terms and index tuples is fixed by constraints.

Re-hash all quads to leaves, recompute root, and assert that it equals root.


## How to run
 bb prove -b ./target/noir_selective_disclosure_test.json -w ./target/noir_selective_disclosure_test.gz --write_vk -o ./target/proof --output_format bytes_and_fields
AND
 bb verify -p ./target/proof/proof -k ./target/proof/vk -i ./target/proof/public_inputs

## Finding

As we are proving membership to a signed root in-circuit, we need the index of the triple in said signed root (Merkle tree roots are order-sensitive).

If the Prover passes them in a different order than sorted, we need to include a mapping from sorted to unsorted indexing.
If the verifier passes a different order of ---- fails

This means, that the public inputs [disclosed_terms[K], disclosed_positions[K][quad_idx, pos_idx]] leak ordering information regarding the signed Merkle tree root. Unlinkability cannot be guaranteed(???). 
=> Solution: Treat publicly disclosed RDF terms as unordered multisets to preserve unlinkability???

### Test case: Prover-side reordering

if the prover builds the witness with one order of disclosed_terms, but the verifier supplies a different order as public inputs, verification fails.

If only quad indices are re-ordered and position indices are kept the same, verification still fails; the order is part of the statement being proven.

### Possible solutions:

A. Inside the circuit, prove there exists some leaf whose coordinate at position_id equals disclosed_term, using a private Merkle path inclusion proof and a private index. This reduces public inputs to disclosed_terms and corresponding position_id. 

This results in a more RDF-like statement for the proof: “this value occurs in some triple at position p” rather than “in triple number i at position p”. Full statement becomes: For each disclosed term hash, there exists some quad in the signed dataset such that quad[position_id] = disclosed_term. Quad indices are no longer publicly leaked.

Benefits of using merkle paths include a computation cost of O(K * TREE_DEPTH) constraints. THis means that the circuit constraint size scales with disclosed terms not size of the dataset.

However this still does not allow arbitrary ordering of public inputs (disclosed terms), because disclosed term order must still equal the backing_quads order to assert position and match the leaf with the correct merkle_path and merkle_indices needed to verify quad membership of the signed merkle root.


B. Randomized Issuer ordering paired with canonical ordering of public inputs.

Again, mapping needed from ordered public input term to shuffled triple that was used to copmute the signed merkle tree root.

C. In-circuit permutation checks to prove that the ordered public input "presentation triples" are a permutation of the shuffled dataset (which was used to sign the merkle tree root).
Difficult...
