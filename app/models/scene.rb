class Scene < ApplicationRecord
  include Filterable
  include Taggable

  has_and_belongs_to_many :performers
  has_one :gallery, as: :ownable
  belongs_to :studio, optional: true

  scoped_search on: [:title, :details, :path, :checksum, :rating]

  default_scope { order(path: :asc) }
  scope :filter_studios, -> (studio_ids) { where studio_id: studio_ids }
  scope :filter_performers, -> (performer_ids) { joins(:performers).where('performers.id IN (?)', performer_ids).distinct }
  scope :filter_tags, -> (tag_ids) { joins(:tags).where('tags.id IN (?)', tag_ids).distinct }
  scope :filter_rating, -> (rating) { where('rating >= ?', rating) }
  scope :filter_missing, -> (missing) {
    if missing.first == 'gallery'
      missing_gallery
    else
      where missing.first.to_sym => nil
    end
  }
  scope :resolution, -> (resolution) {
    resolution = resolution.first if resolution.is_a?(Array)
    if resolution == '240p'
      where('height >= 240 AND height < 480')
    elsif resolution == '480p'
      where('height >= 480 AND height < 720')
    elsif resolution == '720p'
      where('height >= 720 AND height < 1080')
    elsif resolution == '1080p'
      where('height >= 1080 AND height < 2160')
    elsif resolution == '4k'
      where('height >= 2160')
    else
      where('height < 240')
    end
  }

  scope :missing_gallery, -> () { joins('LEFT OUTER JOIN galleries ON galleries.ownable_id = scenes.id').where('galleries.ownable_id IS NULL') }

  def mime_type
    return Mime::Type.lookup_by_extension(File.extname(path).delete('.')).to_s
  end

  def chapter_vtt
    # TODO Get real chapter markers working here
    markers = [100, 400, 800]
    messages = ["First message", "Seconds", "Third message here"]

    i = 0
    vtt = ["WEBVTT",""]
    markers.count do |seconds|
      vtt.push("#{get_vtt_time(seconds)} --> #{get_vtt_time(seconds)}")
      vtt.push(messages[i])
      vtt.push("")
      i = i + 1
    end

    vtt.join("\n")
  end

  def is_streamable
    valid = mime_type == "video/quicktime" || mime_type == "video/mp4" || mime_type == "video/webm"

    if !valid
      path = File.join(StashMetadata::STASH_TRANSCODE_DIRECTORY, "#{self.checksum}.mp4")
      valid = File.exist?(path)
    end

    return valid
  end

  def screenshot(seconds: nil, width: nil)
    cache_key = "#{checksum}"
    if seconds
      cache_key = cache_key + "_#{seconds}"
    end
    if width
      cache_key = cache_key + "_#{width}"
    end

    unless Rails.cache.read(cache_key).nil?
      return Rails.cache.read(cache_key)
    else
      data = StashMetadata::FFMPEG.screenshot(path: path, seconds: seconds, width: width)
      Rails.cache.write(cache_key, data)
      return data
    end
  end

  private

    def get_vtt_time(seconds)
      Time.at(seconds).gmtime.strftime('%H:%M:%S')
    end
end
