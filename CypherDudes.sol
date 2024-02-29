// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {File, Content} from "./ethfs/File.sol";

error NotTheOwner(string filename, address caller);
error NotAuthorized();
error MaxSupplyReached();
error SupplyLocked();

interface ICypherdudesFileStore {
    function storeFile(string calldata filename, bytes calldata content) external returns(File memory file);
    function deleteCard(string calldata filename) external;
    function readFile(string calldata filename) external view returns(string memory content);
    error NottheOwner(string filename, address wrongAddress);
}

interface ICypherDudesRenderer {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// Returns the decimal string representation of value
function itoa(uint value) pure returns (string memory) {

  // Count the length of the decimal string representation
  uint length = 1;
  uint v = value;
  while ((v /= 10) != 0) { length++; }

  // Allocated enough bytes
  bytes memory result = new bytes(length);

  // Place each ASCII string character in the string,
  // right to left
  while (true) {
    length--;

    // The ASCII value of the modulo 10 value
    result[length] = bytes1(uint8(0x30 + (value % 10)));

    value /= 10;

    if (length == 0) { break; }
  }

  return string(result);
}

/// @title CypherDudes
/// @author @felixfelixfelix

contract CypherDudes is ERC721Royalty, Ownable {
    using SafeCast for uint256;

    uint256 public totalSupply = 0;
    uint256 public maxSupply;
    uint256 public cost = 0.031337 ether;


    uint private constant MAX_SALE = 1792;
    uint private constant MAX_GIFT = 256;

    bytes32 public merkleRoot;

    uint256 public publicSaleStartTime = 1708621200000;
    uint256 public wlSaleStartTime = 1708614000000;

/// @dev Token variable to generate traits and track the progression
    struct TokenData {
        uint256 seed;
        uint256 globalProgression;
        string secretWord;
    }

/// @dev EIP-2098 compact signature representation
    struct SignatureCompact {
        bytes32 r;
        bytes32 yParityAndS;
    }

    ICypherdudesFileStore public fileStore;
    ICypherDudesRenderer public renderer;

/// @dev Mapping from token ID to token data
    mapping(uint256 => TokenData) public tokenData;

    constructor(
        address filestore_,
        address cypherdudesRenderer
    ) ERC721("CypherDudes", "CYD") Ownable(msg.sender) {
        maxSupply = 2048;
        fileStore = ICypherdudesFileStore(filestore_);
        renderer = ICypherDudesRenderer(cypherdudesRenderer);
        _setDefaultRoyalty(msg.sender, 500);
    }

    function setMerkleRoot(bytes32 _root) public onlyOwner {
        merkleRoot = _root;
    }

    /// @dev Reentrancy protection
    modifier callerIsUser(){
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    /// @dev Whitelist managment
    function isWhiteListed(address _account, bytes32[] calldata _proof) internal view returns(bool){
        return _verify(leaf(_account), _proof);
    }

    function leaf(address _account) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(_account));
    }

    function _verify(bytes32 _leaf, bytes32[] memory _proof) internal view returns(bool){
        return MerkleProof.verify(_proof, merkleRoot, _leaf);
    }
    
    /// @dev contract dependency managment
    function setFileStoreContract(address _FileStoreContract) public onlyOwner{
        fileStore = ICypherdudesFileStore(_FileStoreContract);
    }
    function setRenderer(address _cypherdudesRenderer) public onlyOwner{
        renderer = ICypherDudesRenderer(_cypherdudesRenderer);
    }
    
    /// @dev internal mint function
    function mint() internal {
        if (totalSupply >= maxSupply-320) revert MaxSupplyReached();
        if (_msgSender() == owner()) revert NotAuthorized();

        uint256 _tokenId = totalSupply;
        totalSupply++;
        uint256 seed = uint256(keccak256(abi.encodePacked( block.number, block.timestamp, _msgSender(), _tokenId)));
        tokenData[_tokenId].globalProgression = seed%192 + 1;
        seed >>=8;
        tokenData[_tokenId].seed = seed;
        tokenData[_tokenId].secretWord = "";
        //
        fileStore.storeFile(string.concat("cypherCard_",toString(_tokenId)), "0x02797021a27e3f37a6631267647187c784f4a893cede9fd11089b7be3fefa5e972e0776cbe6bef2990c009a41138469675399bdba49c5e979e46aec7095cf428ccde43f6060c320d6680b73432f757d8660bbdd1e4144638fdb516b74fa77778ac8c65c42bed2d9176ed6cf973961bd1ba0d6b0bc548fdf583b645adb6f737e5c68abd277d3381484333309d3cc785091b92850f4c29f1f32dcd098d0adcdc70999a86c099b4b2a6a8333f764737ba6c0674375064b04ed8336e0f7bf6ab05a0");
        _safeMint(_msgSender(), _tokenId);
    }

    /// @dev Whitelist mint function
    function whitelistMint(uint256 _quantity, bytes32[] calldata _proof) external payable callerIsUser{
        require(block.timestamp < wlSaleStartTime, "WhiteList Sale is not activated");
        require(isWhiteListed(_msgSender(), _proof), "Not Whitelisted");
        require(totalSupply + _quantity <= MAX_SALE, "Not enough Cypherdudes left");
        require(_quantity >= 1, "No minting request");
        require(msg.value >= _quantity * 0.031337 ether, "Not enough funds");
        uint256 i;
        do {
            mint();
            unchecked{++i;}
        } while (i < _quantity);
    }

    /// @dev Public mint function
    function publicMint(uint256 _quantity) external payable callerIsUser{
        require(block.timestamp < publicSaleStartTime, "Public sale not activated");
        require(totalSupply + _quantity <= MAX_SALE, "Not enough Cypherdudes left");
        require(_quantity >= 1, "No minting request");
        require(msg.value >= _quantity * 0.031337 ether, "Not enough funds");
        uint256 i;
        do {
            mint();
            unchecked{++i;}
        } while (i < _quantity);
    }

    /// @dev Owner mint function
    function gift(uint256 _quantity) external onlyOwner{
        require(block.timestamp > publicSaleStartTime, "Gift not possible yet");
        uint256 i;
        do {
            mint();
            unchecked{++i;}
        } while (i < _quantity);
    }

    /// @dev sale starts managment
    function setWlSaleStart(uint256 _time) public onlyOwner{
        wlSaleStartTime = _time;
    }

    function setPublicSaleStart(uint256 _time) public onlyOwner{
        publicSaleStartTime = _time;
    }

    /// @dev withdraw contract balance
    function withdraw() public payable onlyOwner {
        require(payable(_msgSender()).send(address(this).balance));
    }

    /// @dev claims the words from the offchain list after signature validation
    function signedClaimWord(string calldata word, SignatureCompact calldata sig, uint256 tokenId) public {
        // Decompose the EIP-2098 signature (the struct is 64 bytes in length)
        uint8 v = 27 + uint8(uint256(sig.yParityAndS) >> 255);
        bytes32 s = bytes32((uint256(sig.yParityAndS) << 1) >> 1);

        address caller = _ecrecover(word, v, sig.r, s);

        if (caller == ownerOf(tokenId)){
            tokenData[tokenId].secretWord = word;
        } else {
            revert NotAuthorized();
        }
    }
    
    /// @dev read the message writen on the card
    function readCard(uint256 tokenId) public view returns(string memory content){
        return fileStore.readFile(string.concat("cypherCard_",toString(tokenId)));
    }

    /// @dev writes the message on the card
    function writeCard(uint256 tokenId, bytes memory content) public returns(File memory file){
        string memory filename = string.concat("cypherCard_",toString(tokenId));
        if(ownerOf(tokenId) == msg.sender){
            fileStore.deleteCard(filename);
            if(tokenData[tokenId].globalProgression < 289){
                ++tokenData[tokenId].globalProgression;
            }
            return fileStore.storeFile(filename, content);
        } else {
            revert NotTheOwner(filename, msg.sender);
            }
    }

    /// @dev calls the renderer token URI function
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return renderer.tokenURI(tokenId);
    }

    /// @dev Decryption main function
    function encrypt(string memory key, string memory message) public pure returns(bytes memory mainHash){
       bytes memory hash = abi.encode(key, message);
       bytes memory hashedRecipient = abi.encode(key);

       return translate(hash, hashedRecipient);
   }

   /// @dev Decryption main function
   function decrypt(string memory key,bytes memory hash) public pure returns(string memory _message) {
       bytes memory hashedRecipient = abi.encode(key);
       bytes memory hashedMessage = translate(hash, hashedRecipient);

       return _message = read(hashedMessage);

   }

   /// @dev decode and extract message
   function read(bytes memory hash) private pure returns (string memory _message){
       (, _message) = abi.decode(hash, (string, string));
           return _message;  
   }

   /// @dev Bidirectional Encryption function
   function translate (bytes memory data, bytes memory key) private pure returns (bytes memory result) {
   // Store data length on stack for later use
   uint256 length = data.length;

   assembly {
       // Set result to free memory pointer
       result := mload (0x40)
       // Increase free memory pointer by lenght + 32
       mstore (0x40, add (add (result, length), 32))
       // Set result length
       mstore (result, length)
   }

   // Iterate over the data stepping by 32 bytes
   for (uint i = 0; i < length; i += 32) {
       // Generate hash of the key and offset
       bytes32 hash = keccak256 (abi.encodePacked (key, i));

       bytes32 chunk;
       assembly {
       // Read 32-bytes data chunk
       chunk := mload (add (data, add (i, 32)))
       }
       // XOR the chunk with hash
       chunk ^= hash;
       assembly {
       // Write 32-byte encrypted chunk
       mstore (add (result, add (i, 32)), chunk)
       }
   }
   }
    /// @dev Helper function to convert uint256 into string
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
 
        uint256 temp = value;
        uint256 digits;
 
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
 
        bytes memory buffer = new bytes(digits);
 
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
 
        return string(buffer);
    }

    /// @dev Signer function
    function _ecrecover(string memory message, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        // Compute the EIP-191 prefixed message
        bytes memory prefixedMessage = abi.encodePacked(
        "\x19Ethereum Signed Message:\n",
        itoa(bytes(message).length),
        message
        );

        // Compute the message digest
        bytes32 digest = keccak256(prefixedMessage);

        // Use the native ecrecover provided by the EVM
        return ecrecover(digest, v, r, s);
    }

}
