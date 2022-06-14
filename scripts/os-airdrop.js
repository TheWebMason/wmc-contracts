const fs = require('fs');
const { utils } = require('ethers');
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const BN = require('bignumber.js');



// Generate the list of whitelisted user and amount qualified
let airdropList = [
  { address: "0xDcE61Fe7a22035c7b6De1c8Ebdb8303Ce7D447c7", amount: 10, },
  { address: "0xdE3a4d50b2c77CDd1BFb5F5ea0A3e994C6240ea7", amount: 20, },
  { address: "0x66a12469850b69860c467B20950b6d0B081e6a3b", amount: 30, },
  { address: "0x178421598718CE2845A67e251D9E40b39af01258", amount: 40, },
];
//let airdropList = JSON.parse(fs.readFileSync('./data/list.json', { encoding: 'utf8' }));

// Fix list
let total = new BN('0');
airdropList = airdropList.map((x) => {
  total = total.plus(x.amount);
  return {
    address: x.address.toLowerCase(),
    amount: utils.parseEther(x.amount.toString()).toString(),
  };
});

// Check duplication
for (let i in airdropList) {
  let found = 0;
  for (let j in airdropList) {
    if (airdropList[i].address === airdropList[j].address) {
      found += 1;
    }
  }

  if (found !== 1) {
    throw new Error('Address duplication: ' + airdropList[i].address);
  }
}

// Encode the datastructure
const elements = airdropList.map((x) => {
  return utils.solidityKeccak256(["address", "uint256"], [x.address, x.amount]);
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

// Add proof
for (let i in elements) {
  airdropList[i].proof = merkleTree.getHexProof(elements[i]);
}

fs.mkdirSync('./data', { recursive: true, });
fs.writeFileSync('./data/airdrop_root.txt', root);
fs.writeFileSync('./data/airdrop_list.json', JSON.stringify(airdropList, null, 2));

console.log('Done!\nTotal addresses: %d.\nTotal WMC: %s.', airdropList.length, total.toString());
