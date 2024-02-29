// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {SSTORE2} from "./solady/utils/SSTORE2.sol";
import {ICypherdudesFileStore} from "./ICypherdudesFileStore.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {File, Content} from "./File.sol";
import {IContentStore} from "./IContentStore.sol";

interface ICypherDudes {
    struct TokenData {
        string cypherCard;
    }
    function tokenData(
        uint256 tokenId
    ) external view returns( string memory);
}

contract CypherdudesFileStore is ICypherdudesFileStore, Ownable {
    IContentStore public immutable contentStore;
    ICypherDudes public cypherDudesContract;
    address cypherDudesContractAddy;

    // filename => File checksum
    mapping(string => bytes32) public files;

    constructor(IContentStore _contentStore) Ownable(msg.sender){
        contentStore = _contentStore;
    }

    function setCypherCardContract(address _cypherCardContract) public onlyOwner{
        cypherDudesContract = ICypherDudes(_cypherCardContract);
        cypherDudesContractAddy = _cypherCardContract;
    }

    function fileExists(string memory filename) public view returns (bool) {
        return files[filename] != bytes32(0);
    }

    function getChecksum(string memory filename)
        public
        view
        returns (bytes32 checksum)
    {
        checksum = files[filename];
        if (checksum == bytes32(0)) {
            revert FileNotFound(filename);
        }
        return checksum;
    }

    function getFile(string memory filename)
        public
        view
        returns (File memory file)
    {
        bytes32 checksum = files[filename];
        if (checksum == bytes32(0)) {
            revert FileNotFound(filename);
        }
        address pointer = contentStore.pointers(checksum);
        if (pointer == address(0)) {
            revert FileNotFound(filename);
        }
        return abi.decode(SSTORE2.read(pointer), (File));
    }

    function readFile(string memory filename) public view returns (string memory content){
        return getFile(filename).read();
    }

    function storeFile(string memory filename, bytes memory content) public returns(File memory file) {
        (bytes32 checksum,) = contentStore.addContent(content);
        bytes32[] memory checksums = new bytes32[](1);
        checksums[0] = checksum;
        return createFile(filename, checksums);
    }

    function createFile(string memory filename, bytes32[] memory checksums)
        public
        returns (File memory file)
    {
        return createFile(filename, checksums, new bytes(0));
    }

    function createFile(
        string memory filename,
        bytes32[] memory checksums,
        bytes memory extraData
    ) public returns (File memory file) {
        if (files[filename] != bytes32(0)) {
            revert FilenameExists(filename);
        }
        return _createFile(filename, checksums, extraData);
    }

    function _createFile(
        string memory filename,
        bytes32[] memory checksums,
        bytes memory extraData
    ) private returns (File memory file) {
        Content[] memory contents = new Content[](checksums.length);
        uint256 size = 0;
        // TODO: optimize this
        for (uint256 i = 0; i < checksums.length; ++i) {
            size += contentStore.contentLength(checksums[i]);
            contents[i] = Content({
                checksum: checksums[i],
                pointer: contentStore.getPointer(checksums[i])
            });
        }
        if (size == 0) {
            revert EmptyFile();
        }
        file = File({size: size, contents: contents});
        (bytes32 checksum,) = contentStore.addContent(abi.encode(file));
        files[filename] = checksum;
        emit FileCreated(filename, checksum, filename, file.size, extraData);
    }


    function deleteFile(string memory filename) public onlyOwner {
        bytes32 checksum = files[filename];
        if (checksum == bytes32(0)) {
            revert FileNotFound(filename);
        }
        delete files[filename];
        emit FileDeleted(filename, checksum, filename);
    }

    function deleteCard(string memory filename) public {
        if (msg.sender == cypherDudesContractAddy){
            bytes32 checksum = files[filename];
            if (checksum == bytes32(0)) {
                revert FileNotFound(filename);
            }
            delete files[filename];
            emit FileDeleted(filename, checksum, filename);
        } else{
            revert NottheOwner(filename, msg.sender);
        }
        
    }

    function getScript(string memory filename) public view returns (bytes memory script){
        bytes32 checksum = files[filename];
        if (checksum == bytes32(0)) {
            revert FileNotFound(filename);
        }
        address pointer = contentStore.pointers(checksum);
        if (pointer == address(0)) {
            revert FileNotFound(filename);
        }
        return SSTORE2.read(pointer);
    }
}