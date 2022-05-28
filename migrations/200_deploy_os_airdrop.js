const Airdrop = artifacts.require('WebMasonCoinOpenSeaAirdrop');
const Token = artifacts.require('WebMasonCoin');



module.exports = async (deployer) => {
  const args = [Token.address];
  await deployer.deploy(Airdrop, ...args);
};
