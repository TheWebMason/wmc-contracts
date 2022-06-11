const Token = artifacts.require('WebMasonCoin');



module.exports = async (deployer) => {
  await deployer.deploy(Token);
};
