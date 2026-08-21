# WLVDB result contract

WLVPanel reads the immutable publication protocol produced by WLVDB output
contract `wlvpanel-output` v1.0.0. The selected channel defaults to `stable` and can
be changed with `WLV_RELEASE_CHANNEL`, including hierarchical channels such as
`research/input-v3`.

Before opening any modern FST array, `utils/result_contracts.R` resolves and
validates the complete chain:

```text
channels/<channel>/<sequence>-<release_id>.json
  -> releases/<release_id>/release_manifest.json
     -> runs/<method>/<run_id>/run_manifest.json
        -> every declared run artifact
     -> every declared release artifact
```

Validation covers document schemas and versions, canonical relative paths,
identities, exact directory inventories, byte sizes, SHA-256 digests, and
FST/`.meta` pairing. `meta_indicators.csv` and `indicators_en.csv` are read from
the verified release directory. This consumer accepts exactly version 1.0.0;
adopting a later version requires an explicit compatibility change and fixture
update. A present but invalid marker is a hard error;
the panel never falls back to an earlier or legacy generation after detecting
corruption or incompatibility.

During migration only, absence of every marker for the requested channel
enables the old mutable `results/<method>/` reader with an explicit warning.
This fallback should be removed after production results have been regenerated
through the manifested WLVDB publisher. A non-English legacy indicator catalog
may also be used with a warning until translations become release artifacts;
otherwise the verified English catalog is used.

The canonical schemas and shared fixture are maintained in the WLVDB
`contracts/results/` directory. Consumer tests deliberately corrupt each link
of the chain and reject every unsupported output-contract version.
