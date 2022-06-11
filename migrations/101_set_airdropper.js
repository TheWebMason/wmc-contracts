const Token = artifacts.require('WebMasonCoin');



module.exports = async (deployer, network, accounts) => {
  const token = await Token.deployed();
  const args = [accounts[0], true];
  await token.setAirdropper(...args);
};
