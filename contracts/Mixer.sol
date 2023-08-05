// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.0 <0.9.0;

import "./lib/alt_bn128.sol";
import "./Token/Token.sol";
import "./Token/TokenRegistrar.sol";
import "./PubParam.sol";
// import {PartialEquality as PE} from "./ZKP/PartialEquality.sol";
// import {DualRingEC as DR} from "./ZKP/DualRingEC.sol";
// import {DiffGenEqual as DG} from "./ZKP/DiffGenEqual.sol";
import "./TX/SoKdp.sol";
import "./TX/SoKwd.sol";
import "./TX/SoKsp.sol";

contract Mixer {
  
  using alt_bn128 for uint256;
  using alt_bn128 for alt_bn128.G1Point;

  alt_bn128.G1Point[] _accs;
  alt_bn128.G1Point[] _pks;
  alt_bn128.G1Point[] _tags;

  TokenRegistrar r;
  PubParam pp;
  // PE pe;
  // DR dr;
  // DG dg;
  SoKdp dp;
  SoKwd wd;
  SoKsp sp;

  // constructor (
  //   address r_addr, 
  //   address pp_addr, 
  //   address pe_addr, 
  //   address dr_addr,
  //   address dg_addr,
  //   address wd_addr,
  //   address sp_addr
  // ) {
  //   r = TokenRegistrar(r_addr);
  //   pp = PubParam(pp_addr);
  //   pe = PE(pe_addr);
  //   dr = DR(dr_addr);
  //   dg = DG(dg_addr);
  //   wd = SoKwd(wd_addr);
  //   sp = SoKsp(sp_addr);
  // }

  constructor (
    address r_addr, 
    address pp_addr, 
    address dp_addr,
    address wd_addr,
    address sp_addr
  ) {
    r = TokenRegistrar(r_addr);
    pp = PubParam(pp_addr);
    dp = SoKdp(dp_addr);
    wd = SoKwd(wd_addr);
    sp = SoKsp(sp_addr);
  }

  ///////// deposit /////////

  /// @dev user deposit token into mixer
  /// @param tx_dp deposit transaction statement
  /// @param wit witness (sk, opn, ok)
  /// @return sig deposit signature
  function deposit(SoKdp.TX memory tx_dp, uint256[3] memory wit) public returns (SoKdp.Sig memory sig){

    Token t = Token(r.getToken(tx_dp.attrS[0]));

    if (!t.approve(address(this), tx_dp.attrS[1])) 
      revert ("Unsuccessful approve operation");

    sig = dp.sign(tx_dp, wit);
  }

  /// @dev mixer process deposit request
  /// @param tx_dp deposit transaction statement
  /// @param sig deposit signature
  function process_dp(SoKdp.TX memory tx_dp, SoKdp.Sig memory sig) public returns (bool) {
    /// @dev b0 ≜ T_now ∈ [T_begS ,T_endS)
    uint256 time = block.timestamp;
    bool b0 = tx_dp.attrS[2] <= time && time < tx_dp.attrS[3]; 

    /// @dev b1 ≜ pk ∉ Σpk
    bool b1 = !_in(_pks, tx_dp.s.pk);

    /// @dev b2 ≜ SoKverify(L_dp)
    bool b2 = dp.verify(tx_dp, sig);
    require (b2, "SoKdp failed");

    if (b0 && b1 && b2){
      alt_bn128.G1Point memory Cx = tx_dp.s.tcom.add(tx_dp.s.ocom);
      _accs.push(Cx);
      _pks.push(tx_dp.s.pk);
      Token t = Token(r.getToken(tx_dp.attrS[0]));
      return t.transfer(msg.sender, address(this), tx_dp.attrS[1]);
    }
    return false;
  }

  //////// withdraw //////////

  /// @dev withdraw token from mixer
  /// @param tx_wd withdraw transaction statement
  /// @param wit (theta, sk, opn, ok)
  function withdraw(SoKwd.TX memory tx_wd, uint256[4] memory wit) public view returns (SoKwd.Sig memory){
    return wd.sign(tx_wd, wit);
  }
  
  function process_wd(SoKwd.TX memory tx_wd, SoKwd.Sig memory sig) public returns (bool) {
    /// @dev b0 ≜ T_now ∈ [T_begS ,T_endS)
    uint256 time = block.timestamp;
    bool b0 = tx_wd.attrS[2] <= time && time < tx_wd.attrS[3];

    /// @dev b1 = verify signature
    bool b1 = wd.verify(tx_wd, sig);
    require (b1, "SoKwd failed");

    /// @dev b2 ≜ tagS ∉ Σtag
    bool b2 = !_in(_tags, tx_wd.tag);

    if (b0 && b1 && b2) {
      _tags.push(tx_wd.tag);

      Token t = Token(r.getToken(tx_wd.attrS[0]));
      /// @dev ty.transfer[mixer, rcpt]
      return t.transfer(address(this), tx_wd.u_rcpt, tx_wd.attrS[1]);
    }
    return false;
  }

  function spend(SoKsp.TX memory tx_sp, SoKsp.Wit memory wit) public view returns (SoKsp.Sig memory){
    return sp.sign(tx_sp, wit);
  }

  function process_sp(SoKsp.TX memory tx_sp, SoKsp.Sig memory sig) public returns (bool) {
    // uint256 time = 5; // for testing
    /// @dev b0 ≜ T_now ∈ [T_begS ,T_endS)
    uint256 time = block.timestamp;
    bool b0 = tx_sp.attrS[1] <= time && time < tx_sp.attrS[2]; 
    require (b0, "invalid transaction time");

    // b1 ≜ pkT ∉ Σpk
    bool b1 = !_in(_pks, tx_sp.pk_T);

    // b2 ≜ tagS ∉ Σtag
    bool b2 = !_in(_tags, tx_sp.tagS);

    bool b3 = sp.verify(tx_sp, sig);
    require (b3, "SoKsp failed");

    if (b0 && b1 && b2 && b3){
      _tags.push(tx_sp.tagS);
      _pks.push(tx_sp.pk_T);

      alt_bn128.G1Point memory acc;
      for (uint i = 0; i < tx_sp.ocom_T.length; i++) {
        acc = tx_sp.tcom_T[i].add(tx_sp.ocom_T[i]);
        _accs.push(acc);
      }
      return true;
    }
    return false;
  }

  function _in(
    alt_bn128.G1Point[] memory ls, 
    alt_bn128.G1Point memory pk
  ) internal pure returns (bool) {
    for (uint i = 0 ; i < ls.length; i++) {
      if (alt_bn128.eq(ls[i], pk)) return true;
    }
    return false;
  }



}