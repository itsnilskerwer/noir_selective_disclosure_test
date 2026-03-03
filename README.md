In-circuit:

Verify ECDSA on root.

Enforce that each disclosed term hash equals the appropriate coordinate of canonical_quads[quad_idx][coord_idx].

Re-hash all quads to leaves, fold them with Poseidon in the canonical order, and assert that the recomputed root equals root.

Assertions:

Merkle proves positional integrity 

Merkle proves all terms of a given triple share the same quad_idx i.e occur within the same triple.

## How to run
 bb prove -b ./target/noir_selective_disclosure_test.json -w ./target/noir_selective_disclosure_test.gz --write_vk -o ./target/proof --output_format bytes_and_fields
AND
 bb verify -p ./target/proof/proof -k ./target/proof/vk -i ./target/proof/public_inputs

## Finding

Swapping the order of the disclosed input_terms is not possible. As we are proving membership to a signed root in-circuit, we need the index of the triple in said signed root. Correct index is necessary because root is computed in a certain order. 
If the Prover passes them in a different order than sorted, we need to include a mapping from sorted to unsorted indexing.
If the verifier passes a different order of ---- fails