const alt_bn128 = artifacts.require("alt_bn128");
const MixerFactory = artifacts.require("MixerFactory");
const Mixer = artifacts.require("Mixer");
const TokenRegistrar = artifacts.require("TokenRegistrar");
const PartEqual = artifacts.require("PartialEquality");
const DualRing = artifacts.require("DualRingEC");
const OneofMany = artifacts.require("OneofMany");
const DiffGenEqual = artifacts.require("DiffGenEqual");
const Sigma = artifacts.require("Sigma");

const SoKdp = artifacts.require("SoKdp");
const SoKwd = artifacts.require("SoKwd");
const SoKsp = artifacts.require("SoKsp");
const SoKba = artifacts.require("SoKba");
const SoKab = artifacts.require("SoKab");
const PubParam = artifacts.require("PubParam");
const RelayRegistry = artifacts.require("RelayRegistry");

const overwritable = true;

module.exports = async function(deployer, _, accounts){

  await deployer.deploy(alt_bn128, {overwrite: overwritable});

  await deployer.link(alt_bn128,
    [ Mixer, MixerFactory, PubParam,
      DualRing, PartEqual, DiffGenEqual, OneofMany, Sigma
    ]);

  await deployer.link(alt_bn128, [SoKdp, SoKwd, SoKsp, SoKab, SoKba]);

  await deployer.deploy(PubParam, 1, {overwrite: overwritable});
  await deployer.deploy(TokenRegistrar, {overwrite: overwritable});
  await deployer.deploy(RelayRegistry, {overwrite: overwritable});

}