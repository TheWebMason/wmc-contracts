const Token = artifacts.require('WebMasonCoin');
const Airdrop = artifacts.require('WebMasonCoinOpenSeaAirdrop');



module.exports = async (deployer) => {
  const token = await Token.deployed();
  const args = [Airdrop.address, true];
  await token.setAirdropper(...args);
};
