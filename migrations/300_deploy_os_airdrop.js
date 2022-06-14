const Token = artifacts.require('WebMasonCoin');
const Airdrop = artifacts.require('WebMasonCoinOpenSeaAirdrop');



module.exports = async (deployer) => {
  const args = [Token.address];
  await deployer.deploy(Airdrop, ...args);
};
