// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "./ethfs/solady/utils/Base64.sol";
import {File, Content} from "./ethfs/File.sol";
import {IScriptyBuilderV2, HTMLRequest, HTMLTagType, HTMLTag} from "./scripty.sol/interfaces/IScriptyBuilderV2.sol";

interface ICypherDudes {
    struct TokenData {
        uint256 seed;
        uint256 globalProgression;
        string secretWord;
    }
    function tokenData(
        uint256 tokenId
    ) external view returns(uint256, uint256, string memory);

    function ownerOf(uint256 tokenId) external view returns(address);
}

interface IFileStore {
    function readFile(string memory filename) external view returns(string memory content);
    function getFile(string memory filename)
        external
        view
        returns (File memory file);
}

/// @title cypherdudesRenderer
/// @author @felixfelixfelix
contract cypherdudesRenderer is Ownable {
    ICypherDudes public cypherdudesContract;
    IFileStore public fileStore;
    address public immutable scriptyStorageAddress;
    address public immutable scriptyBuilderAddress;
    uint256 private bufferSize;

    string public baseImageURI;
    string public website;

    struct Trait {
        string typeName;
        string valueName;
  }
  constructor(
    address _scriptyBuilderAddress,
    address _scriptyStorageAddress,
    address filestore_,
    uint256 bufferSize_,
    string memory baseImageURI_,
    string memory website_
    ) Ownable(msg.sender){
        scriptyStorageAddress = _scriptyStorageAddress;
        scriptyBuilderAddress = _scriptyBuilderAddress;
        fileStore = IFileStore(filestore_);
        bufferSize = bufferSize_;
        baseImageURI = baseImageURI_;
        website = website_;
    }

  function setcypherdudesContract(address _cypherdudesContract) public onlyOwner {
    cypherdudesContract = ICypherDudes(_cypherdudesContract);
  }

  function setFileStoreContract(address _fileStore) public onlyOwner {
    fileStore = IFileStore(_fileStore);
  }

  function setBaseImageURI(string calldata uri) public onlyOwner {
    baseImageURI = uri;
  }

  function setWebsite(string calldata url) public onlyOwner {
    website = url;
  }

  function getMetadataObject(bytes memory animationUrl, uint256 tokenId, uint256 dude, uint256 layer2) internal view returns(bytes memory){
    string memory tid = toString(tokenId);
    (,,string memory secretWord) = cypherdudesContract.tokenData(tokenId);
    string memory st = '';
    if(bytes(secretWord).length != 0){
      st = ' - ';
    }
    return
      abi.encodePacked(
        '{"name": "',
        secretWord, st, 
        'CYPHERDUDE #',
        tid,
        '", "description":"Cypherdudes is a generative cryptoart series paying tribute to the Cypherpunk movement, which has been campaigning for the protection of privacy on the internet since the early 90s, and was behind the creation of bitcoin in 2008.''This series takes up the graphic universe of a character that I invented and gained some popularity in the crypto art scene : the cryptodude.'
        'A personification of crypto culture, the Cypherdude performs actions that visually translate the expressions and behaviors specific to this ecosystem.'
        'Each work in the series is unique and generated from an algorithm hosted directly on the blockchain. The parameters composing each work are selected from a wide range of elements created individually by myself and combined in a seeded random way. Each seed is determined by the blockchain on mint.'
        'The work and the Message.'
        'Each owner of a work from the series has access to a hidden feature : the ability to inscribe an encrypted message in the work itself. The encryption key is decided by the owner on every inscription. This message can then only be decoded by a recipient knowing the key. This way, the work becomes a veritable tool at the service of its owner, who, by using it, makes it evolve visually using a simple steganographic technique.'
        'The Cypherdudes thus becomes the visual witness to the presence of a message, and its digital security vault.",',
        '"external_url": "',website,'", "image": "',
        baseImageURI,
        tid,
        '.svg"',
        ', "animation_url": "',
        animationUrl,
        '", "attributes": [',
        getJSONAttributes(tokenId,  dude,  layer2),
        "]}"
      );
    }

  function getTokenConstantsScript(
    uint256 tokenId,
    uint256 dude
  ) internal view returns (bytes memory) {
    (uint256 seed,,string memory secretWord) = cypherdudesContract.tokenData(tokenId);
    seed >>=8;
    uint256 layer1 = seed%11;
    seed >>=8;
    seed >>=8;
    uint256 layer3 = dude == 2 || dude == 3 || dude == 8 ? seed%8 : 8;
    seed >>=8;
    uint256 bitEnvironment = seed%9;
    seed >>=8;
    uint256 bitPalette = seed%12;
    return
      abi.encodePacked(
        "let tokenId = ", toString(tokenId), ";",
        "let layer1 = ", toString(layer1), ";",
        "let layer3 = ", toString(layer3), ";",
        "let secretWord = '", secretWord, "';",
        "let bitEnvironment = ", toString(bitEnvironment), ";",
        "let bitPalette = ", toString(bitPalette), ";"
      );
  }

  function getCardConstantsScript( uint256 tokenId) internal view returns(bytes memory){
    (,uint256 globalProgression,) = cypherdudesContract.tokenData(tokenId);
    uint256 gridSize = globalProgression <97? 32: globalProgression < 193 ? 64:128;
    uint256 gridResolution = ((globalProgression -1)/32)%3;
    uint256 levelProgression = globalProgression%32 == 0 ?32:globalProgression%32;
    return
      abi.encodePacked(
        "let gridSize = ", toString(gridSize), ";",
        "let gridResolution = ", toString(gridResolution), ";",
        "let levelProgression = ", toString(levelProgression), ";",
        "let ownerAddy = '", Strings.toHexString(address(cypherdudesContract.ownerOf(tokenId))), "';",
        "let message = '", fileStore.readFile(string.concat("cypherCard_",toString(tokenId))), "';"
      );
  }


  function tokenURI(uint256 tokenId) external view returns (string memory) {
    HTMLTag[] memory bodyTags = new HTMLTag[](8);
    (uint256 seed,,) = cypherdudesContract.tokenData(tokenId);
    uint256 dude = seed%20;
    seed >>=8;
    seed >>=8;
    uint256 layer2 = seed%2 > 0 ? seed%11 : 11;

    HTMLTag[] memory headTags = new HTMLTag[](1);
    headTags[0].tagOpen = "<style>";
    headTags[0].tagContent = "html{overflow:hidden}body{margin:0;padding:0}";
    headTags[0].tagClose = "</style>";

    bodyTags[0].name = dudeFiles[dude];
    bodyTags[0].tagType = HTMLTagType.scriptGZIPBase64DataURI;
    bodyTags[0].contractAddress = scriptyStorageAddress;

    bodyTags[1].name = "CypherDudesLayer1";
    bodyTags[1].tagType = HTMLTagType.script;
    bodyTags[1].contractAddress = scriptyStorageAddress;

    bodyTags[2].name = "CypherDudesFonts";
    bodyTags[2].tagType = HTMLTagType.script;
    bodyTags[2].contractAddress = scriptyStorageAddress;

    bodyTags[3].name = layers_2[layer2];
    bodyTags[3].tagType = HTMLTagType.script;
    bodyTags[3].contractAddress = scriptyStorageAddress;

    bodyTags[4].name = "CypherDudes";
    bodyTags[4].tagType = HTMLTagType.scriptGZIPBase64DataURI;
    bodyTags[4].contractAddress = scriptyStorageAddress;

    bodyTags[5].tagContent = getTokenConstantsScript(tokenId, dude);
    bodyTags[5].tagType = HTMLTagType.script;

    bodyTags[6].tagContent = getCardConstantsScript(tokenId);
    bodyTags[6].tagType = HTMLTagType.script;

    bodyTags[7].name = "gunzipScripts-0.0.1";
    bodyTags[7].tagType = HTMLTagType.script;
    bodyTags[7].contractAddress = scriptyStorageAddress;

    HTMLRequest memory htmlRequest;
    htmlRequest.headTags = headTags;
    htmlRequest.bodyTags = bodyTags;

    bytes memory base64EncodedHTMLDataURI = IScriptyBuilderV2(
            scriptyBuilderAddress
        ).getEncodedHTML(htmlRequest);

    return
      string(
        abi.encodePacked(
          "data:application/json;base64,",
          Base64.encode(getMetadataObject(base64EncodedHTMLDataURI, tokenId,  dude,  layer2))
        )
      );
  }

  function getJSONAttributes(uint256 tokenId, uint256 dude, uint256 layer2) internal view returns (string memory){
    (uint256 seed,uint256 globalProgression,string memory secretWord) = cypherdudesContract.tokenData(tokenId);
    seed >>=8;
    uint256 layer1 = seed%11;
    seed >>=8;
    seed >>=8;
    uint256 layer3 = dude == 2 || dude == 3 || dude == 8 ? seed%8 : 8;
    seed >>=8;
    uint256 bitEnvironment = seed%9;
    seed >>=8;
    uint256 bitPalette = seed%12;
    
    return string(abi.encodePacked(
        '{"trait_type":"Grid Size","value" :"',toString(globalProgression <97? 32: globalProgression < 193 ? 64:128),'"},',
        '{"trait_type":"Grid Resolution","value" :"',grid_Resolution[((globalProgression -1)/32)%3],'"},',
        '{"trait_type":"Level Progression","value" :"',toString(globalProgression%32 == 0 ?32:globalProgression%32),'"},',
        '{"trait_type":"Action","value" :"',dudeActions[dude],'"},',
        '{"trait_type":"Layer 1","value" :"',layers_1[layer1],'"},',
        '{"trait_type":"Layer 2","value" :"',layers_2[layer2],'"},',
        '{"trait_type":"Layer 3","value" :"',layers_3[layer3],'"},',
        '{"trait_type":"Secret Word","value" :"',secretWord,'"},',
        '{"trait_type":"Bit Environment","value" :"',bit_Environment[bitEnvironment],'"},',
        '{"trait_type":"Bit Palette","value" :"',bit_Palette[bitPalette],'"}'
      )
    );
  }

  function toString(uint256 value) internal pure returns (string memory) {
    // Inspired by OraclizeAPI's implementation - MIT licence
    // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

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
      digits -= 1;
      buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
      value /= 10;
    }
    return string(buffer);
  }

  string[] internal grid_Resolution = [
    "High",
    "Medium",
    "Low"
  ];

  string[] internal dudeActions = [
    "Backdoor Dude",
    "Bitruvian Dude",
    "Building Dude",
    "Dude Scrolling",//
    "Fake Dude",
    "Going to Zero Dude",
    "Hashing Dude",
    "Longterm Dude",
    "Over Minting Dude",//
    "Mooning Dude",
    "Pumping Dude",
    "Rabbit Hole Dude",
    "Dude Regulatoors",
    "Eyes on the Charts",
    "Rugged Dude",
    "Scammed Dude",
    "Dude Walking By",
    "Transfer Dude",
    "Follow the Dude",
    "Secret Dude"
  ];
  string[] internal dudeFiles = [
    "Backdoor_Dude",
    "Bitruvian_Dude",
    "Building_Dude",
    "Dude_Scrolling",
    "Fake_Dude",
    "Going_To_Zero_Dude",
    "Hashing_Dude",
    "Longterm_Dude",
    "Over_Minting_Dude",
    "Mooning_Dude",
    "Pumping_Dude",
    "Rabbit_Hole_Dude",
    "Dude_Regulatoors",
    "Eyes_On_The_Chart",
    "Rugged_Dude",
    "Scammed_Dude",
    "Dude_Walking_By",
    "Transfer_Dude",
    "Follow_The_Dude",
    "Secret_Dude"
  ];

  string[] internal layers_1 = [
    "Rare_Pepes",
    "CryptoPunks",
    "Coins_Flow",
    "Chart",
    "Moma_Pixels",
    "Pixelmon_Reveal",
    "Crypto_Space",
    "Crypto_Voxel",
    "Circuit_Board",
    "Uniswap",
    "Mooncats"
  ];

  string[] internal layers_2 = [
    "Gas_Wars",
    "PacMan",
    "Hardware_Wallet",
    "Feels_Good_Man",
    "Game_Over",
    "M3t4m4Sk",
    "Promising_Collab",
    "MaxPain",
    "Green_Chart",
    "Press_That_Mint_Button",
    "Trash_Art",
    "none"
  ];

  string[] internal layers_3 = [
    "Rare_Pepes",
    "Chart",
    "Moma_Pixels",
    "Crypto_Space",
    "Crypto_Voxel",
    "Circuit_Board",
    "Uniswap",
    "MaxPain",
    "none"
  ];

  string[] internal bit_Environment = [
    "32 bits",
    "32 bits animated",
    "64 bits",
    "64 bits animated",
    "Who dis ?",
    "Bitcoin genesis block",
    "Data tunnel",
    "Meta Script",
    "The Cypherpunk"
  ];

  string[] internal bit_Palette = [
    "green, white, black",
    "green, black, white",
    "black, green, white",
    "black, green, green",
    "black, white, white",
    "black, white, green",
    "black, fuschia, aqua",
    "black, white, green",
    "blue, red, black",
    "black, red, yellow",
    "blue, yellow, fuschia",
    "black, white, white"
  ];

}