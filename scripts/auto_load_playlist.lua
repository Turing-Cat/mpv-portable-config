local mp = require 'mp'
local utils = require 'mp.utils'

local loaded = false

local video_extensions = {
    mp4 = true, mkv = true, avi = true, mov = true, wmv = true,
    flv = true, webm = true, m4v = true, mpg = true, mpeg = true,
    ts = true, m2ts = true, vob = true, ogv = true, rmvb = true,
    rm = true, asf = true, divx = true, f4v = true, ["3gp"] = true,
    mts = true, m2t = true, dv = true, qt = true
}

local function get_extension(filename)
    return filename:match("%.([^%.]+)$")
end

local function is_video(filename)
    local ext = get_extension(filename)
    if ext then
        return video_extensions[ext:lower()] == true
    end
    return false
end

local function add_playlist_from_current_dir()
    if loaded then return end

    local path = mp.get_property("path")
    if not path then return end

    -- 如果播放列表已有多个条目，说明用户已手动指定，跳过
    local playlist = mp.get_property_native("playlist")
    if playlist and #playlist > 1 then
        loaded = true
        return
    end

    loaded = true

    local dir, filename = utils.split_path(path)

    -- 只读取当前目录的文件，不递归子目录
    local files = utils.readdir(dir, "files")
    if not files then return end

    local videos = {}
    for _, f in ipairs(files) do
        if is_video(f) then
            table.insert(videos, f)
        end
    end
    table.sort(videos)

    -- 找到当前文件，将其后的视频依次追加到播放列表
    local found = false
    for _, f in ipairs(videos) do
        if found then
            local fullpath = utils.join_path(dir, f)
            mp.commandv("loadfile", fullpath, "append")
        end
        if f == filename then
            found = true
        end
    end
end

mp.register_event("file-loaded", add_playlist_from_current_dir)
