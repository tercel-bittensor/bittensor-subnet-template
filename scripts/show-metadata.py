import json
from substrateinterface import SubstrateInterface

substrate = SubstrateInterface(
    url="ws://127.0.0.1:9944",
    type_registry_preset='substrate-node-template'
)

metadata = substrate.get_metadata()
# get the second element (dict)
metadata_dict = metadata.value[1]

# save to metadata.json
with open("metadata.json", "w") as f:
    json.dump(metadata_dict, f, indent=2)

print("metadata.json saved")