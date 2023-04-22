// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Chat {
    struct MsgSign {
        uint256 r;
        uint256 s;
        uint256 z;
    }
    mapping(address => MsgSign[]) public signs;
    address[] private participants;
    bool private locked;

    function add(address[] calldata signers, uint256[] calldata r, uint256[] calldata s, uint256[] calldata z) external {
        require(!locked);
        locked = true;
        uint256 sig_iter = 0;
        require(r.length == s.length);
        require(s.length == z.length);
        require(signers.length*10 == r.length);
        for(uint256 i=0; i < signers.length; i++){
            participants.push(signers[i]);
            for(uint8 j=0; j<10; j++){
                signs[signers[i]].push(MsgSign(r[sig_iter], s[sig_iter], z[sig_iter]));
                sig_iter++;
            }
        }
    }

    function getRandomParticipant() external view returns (address) {
        uint256 i = uint256(keccak256(abi.encodePacked(block.timestamp))) %
            participants.length;
        return participants[i];
    }

}

contract AnySwap {
    address public owner;
    address public immutable chat;

    constructor(address _owner, address _chat) {
        owner = _owner;
        chat = _chat;
    }

    function transferOwnership(address _newOwner) external {
        require(msg.sender == owner);
        owner = _newOwner;
    }

    function solved(address player) external returns (bool) {
        return player == owner;
    } 
}
