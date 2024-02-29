// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {File} from "./File.sol";
import {IContentStore} from "./IContentStore.sol";

interface ICypherdudesFileStore {
    event FileCreated(
        string indexed indexedFilename,
        bytes32 indexed checksum,
        string filename,
        uint256 size,
        bytes metadata
    );
    event FileDeleted(
        string indexed indexedFilename,
        bytes32 indexed checksum,
        string filename
    );

    error NottheOwner(string filename, address wrongAddress);
    error FileNotFound(string filename);
    error FilenameExists(string filename);
    error EmptyFile();

    function contentStore() external view returns (IContentStore);


    function files(string memory filename)
        external
        view
        returns (bytes32 checksum);

    function fileExists(string memory filename) external view returns (bool);

    function getChecksum(string memory filename)
        external
        view
        returns (bytes32 checksum);

    function getFile(string memory filename)
        external
        view
        returns (File memory file);

    function createFile(string memory filename, bytes32[] memory checksums)
        external
        returns (File memory file);

    function createFile(
        string memory filename,
        bytes32[] memory checksums,
        bytes memory extraData
    ) external returns (File memory file);

    function deleteFile(string memory filename) external;

    function deleteCard(string memory filename) external;

    function getScript(string memory filename) external view returns (bytes memory script);
}