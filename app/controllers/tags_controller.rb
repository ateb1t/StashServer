class TagsController < ApplicationController
  before_action :set_tag, only: [:show]

  def index
    @tags = Tag.search_for(params[:q])
               .page(params[:page])
               .per(params[:per_page])
  end

  def show
  end

  def new
    @tag = Tag.new
  end

  def create
    @tag = Tag.new(tag_params)
    respond_to do |format|
      if @tag.save
        format.html { redirect_to tags_path, notice: 'Tag was successfully created.' }
      else
        format.html { render :new }
      end
    end
  end

  private

    def set_tag
      @tag = Tag.find(params[:id])
    end

    def tag_params
      params.fetch(:tag).permit(:name)
    end
end
