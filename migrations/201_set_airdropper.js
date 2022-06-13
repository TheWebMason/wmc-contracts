const Token = artifacts.require('WebMasonCoin');
const Safe = artifacts.require('WebMasonCoinSafe');



module.exports = async (deployer) => {
  const token = await Token.deployed();
  const args = [Safe.address, true];
  await token.setAirdropper(...args);
};
