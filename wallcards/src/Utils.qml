import QtQuick

QtObject {
    property var filterImages: []
    property var filterVideos: []

    function getExtension(fileName) {
        return fileName.substring(fileName.lastIndexOf(".") + 1).toLowerCase();
    }

    function isVideo(fileName) {
        return filterVideos.indexOf(getExtension(fileName)) !== -1;
    }

    function isImage(fileName) {
        return filterImages.indexOf(getExtension(fileName)) !== -1;
    }

    function thumbnailName(fileName) {
        return isVideo(fileName)
            ? fileName.substring(0, fileName.lastIndexOf(".")) + ".jpg"
            : fileName;
    }

    function matchesFilter(fileName, selectedFilter) {
        if (selectedFilter === "all") return true;
        if (selectedFilter === "images") return isImage(fileName);
        if (selectedFilter === "videos") return isVideo(fileName);
        return false;
    }

    function nameFilters() {
        return (filterImages || []).concat(filterVideos || []).map(function(ext) {
            return "*." + ext;
        });
    }
}
