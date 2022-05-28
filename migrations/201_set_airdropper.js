const Airdrop = artifacts.require('WebMasonCoinOpenSeaAirdrop');
const Token = artifacts.require('WebMasonCoin');



module.exports = async (deployer) => {
  const token = await Token.deployed();
  const args = [Airdrop.address, true];
  await token.setAirdropper(Airdrop, ...args);
};
