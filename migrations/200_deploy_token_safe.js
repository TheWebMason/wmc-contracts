const Token = artifacts.require('WebMasonCoin');
const Safe = artifacts.require('WebMasonCoinSafe');



module.exports = async (deployer, network, accounts) => {
  let wallet = accounts[0];
  let proxyRegistry = '0x0000000000000000000000000000000000000000';
  if (network === 'development') {
    proxyRegistry = '0x0000000000000000000000000000000000000000';
  } else if (network === 'rinkeby') {
    proxyRegistry = '0xf57b2c51ded3a29e6891aba85459d600256cf317';
  } else if (network === 'mainnet') {
    wallet = '0xaCE491eF8BC4d8F6735A4177560677F9592505e9'; // gnosis safe
    proxyRegistry = '0xa5409ec958c83c3f309868babaca7c86dcb077c1';
  }

  const args = [Token.address, wallet, proxyRegistry];
  await deployer.deploy(Safe, ...args);
};
