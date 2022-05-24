const fs = require('fs');
const { utils } = require('ethers');
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');



// Generate the list of whitelisted user and amount qualified
//let airdropList = JSON.parse(fs.readFileSync('./data/list.json', { encoding: 'utf8' }));
let airdropList = [
  { address: "0xD08c8e6d78a1f64B1796d6DC3137B19665cb6F1F", amount: 10, },
  { address: "0xb7D15753D3F76e7C892B63db6b4729f700C01298", amount: 20, },
  { address: "0xf69Ca530Cd4849e3d1329FBEC06787a96a3f9A68", amount: 30, },
  { address: "0xa8532aAa27E9f7c3a96d754674c99F1E2f824800", amount: 40, },
];

// Fix list
airdropList = airdropList.map((x) => {
  return {
    address: x.address.toLowerCase(),
    amount: utils.parseEther(x.amount.toString()).toString(),
  };
});
for (let i in airdropList) {
  let found = 0;
  for (let j in airdropList) {
    if (airdropList[i].address === airdropList[j].address) {
      found += 1;
    }
  }

  if (found !== 1) {
    throw new Error('Address duplication');
  }
}

// Encode the datastructure
const elements = airdropList.map((x) => {
  return utils.solidityKeccak256(["address", "uint96"], [x.address, x.amount]);
});
const merkleTree = new MerkleTree(elements, keccak256, { sort: true });
const root = merkleTree.getHexRoot();

/*
console.log('root', root);
const leaf = elements[0];
console.log('leaf', leaf);
const proof = merkleTree.getHexProof(leaf);
console.log('proof', proof);
*/

// add proof
for (let i in elements) {
  airdropList[i].proof = merkleTree.getHexProof(elements[i]);
}

fs.mkdirSync('./data', { recursive: true, });
fs.writeFileSync('./data/airdrop_root.txt', root);
fs.writeFileSync('./data/airdrop_list.json', JSON.stringify(airdropList, null, 2));

console.log('Done!');
