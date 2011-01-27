class Admin::ResourcesController < Admin::BaseController

  include Typus::Actions
  include Typus::Filters
  include Typus::Format

  before_filter :get_model
  before_filter :set_scope
  before_filter :get_object, :only => [:show, :edit, :update, :destroy, :toggle, :position, :relate, :unrelate, :detach]
  before_filter :check_resource_ownership, :only => [:edit, :update, :destroy, :toggle, :position, :relate, :unrelate ]
  before_filter :check_if_user_can_perform_action_on_resources
  before_filter :set_order, :only => [:index]
  before_filter :set_fields, :only => [:index, :new, :edit, :create, :update, :show, :detach]

  before_filter :check_if_we_can_add_a_new_item, :only => [:new, :create]

  ##
  # This is the main index of the model. With filters, conditions and more.
  #
  # By default application can respond to html, csv and xml, but you can add
  # your formats.
  #
  def index
    add_resource_action(default_action.titleize, {:action => default_action}, {})
    add_resource_action("Trash", {:action => "destroy"}, {:confirm => "#{Typus::I18n.t("Trash")}?", :method => 'delete'})

    get_objects

    respond_to do |format|
      format.html { generate_html }
      @resource.typus_export_formats.each { |f| format.send(f) { send("generate_#{f}") } }
    end
  end

  def new
    item_params = params.dup
    item_params.delete_if { |k, v| !@resource.columns.map(&:name).include?(k) }
    @item = @resource.new(item_params)
  end

  ##
  # Create new items. There's an special case when we create an item from
  # another item. In this case, after the item is created we also create the
  # relationship between these items.
  #
  def create
    @item = @resource.new(params[@object_name])

    set_attributes_on_create

    if @item.save
      params[:back_to] ? create_with_back_to : redirect_on_success
    else
      render :new
    end
  end

  def edit
    add_resource_action(default_action.titleize, {:action => default_action}, {})
    add_resource_action("Unrelate", {:action => "unrelate", :resource => @resource.model_name, :resource_id => @item.id}, {:confirm => "#{Typus::I18n.t("Unrelate")}?"})
  end

  def show
    check_resource_ownership if @resource.typus_options_for(:only_user_items)
  end

  def update
    respond_to do |format|
      if @item.update_attributes(params[@object_name])
        set_attributes_on_update
        reload_locales
        format.html { redirect_on_success }
        format.json { render :json => @item }
      else
        format.html { render :edit }
        format.json { render :json => @item.errors.full_messages }
      end
    end
  end

  def detach
    if @item.update_attributes(params[:attribute] => nil)
      notice = Typus::I18n.t("%{model} successfully updated.", :model => @resource.model_name.human)
      redirect_to :back, :notice => notice
    else
      render :edit
    end
  end

  def destroy
    if @item.destroy
      notice = Typus::I18n.t("%{model} successfully removed.", :model => @resource.model_name.human)
    else
      alert = @item.errors.full_messages
    end
    redirect_to set_path, :notice => notice, :alert => alert
  end

  def toggle
    @item.toggle(params[:field])
    @item.save!

    notice = Typus::I18n.t("%{model} successfully updated.", :model => @resource.model_name.human)

    respond_to do |format|
      format.html { redirect_to set_path, :notice => notice }
      format.json { render :json => @item }
    end
  end

  ##
  # Change item position:
  #
  #   params[:go] = 'move_to_top'
  #
  # Available positions are move_to_top, move_higher, move_lower, move_to_bottom.
  #
  # NOTE: Only works if `acts_as_list` is installed.
  #
  def position
    @item.send(params[:go])
    notice = Typus::I18n.t("%{model} successfully updated.", :model => @resource.model_name.human)
    redirect_to set_path, :notice => notice
  end

  ##
  # Action to relate models which respond to:
  #
  #   - has_and_belongs_to_many
  #   - has_many
  #
  # For example:
  #
  #   class Item < ActiveRecord::Base
  #     has_many :line_items
  #   end
  #
  #   class LineItem < ActiveRecord::Base
  #     belongs_to :item
  #   end
  #
  #   >> related_item = LineItem.find(params[:related][:id])
  #   => ...
  #   >> item = Item.find(params[:id])
  #   => ...
  #   >> item.line_items << related_item
  #   => ...
  #
  def relate
    resource_class = params[:related][:model].typus_constantize
    association_name = params[:related][:association_name].tableize

    if @item.send(association_name) << resource_class.find(params[:related][:id])
      flash[:notice] = Typus::I18n.t("%{model} successfully updated.", :model => @resource.model_name.human)
    end

    redirect_to set_path
  end

  ##
  # Action to unrelate models which respond to:
  #
  #   - has_and_belongs_to_many
  #   - has_many
  #   - has_one
  #
  def unrelate

    ##
    # Find the remote object which is named item!
    #

    item_class = params[:resource].typus_constantize
    item = item_class.find(params[:resource_id])

    ##
    # Detect which kind of relationship there's between both models.
    #
    #     item respect @item
    #

    # This is not nil in case of a has_many :through association.
    association_name = params[:association_name].to_sym unless params[:association_name].blank?

    case item_class.relationship_with(@resource)
    when :has_one
      association_name = @resource.model_name.underscore.to_sym
      worked = item.send(association_name).delete
    else
      association_name ||= @resource.model_name.tableize.to_sym
      worked = item.send(association_name).delete(@item)
    end

    ##
    # Finally delete the associated object. Depending on your models setup
    # associated models will be removed or foreign_key will be set to nil.
    #

    if worked
      notice = Typus::I18n.t("%{model} successfully updated.", :model => item_class.model_name.human)
    else
      alert = item.error.full_messages
    end

    redirect_to set_path, :notice => notice, :alert => alert
  end

  private

  def get_model
    @resource = params[:controller].extract_class
    @object_name = ActiveModel::Naming.singular(@resource)
  end

  def set_scope
    @resource = @resource.unscoped
  end

  def get_object
    @item = @resource.find(params[:id])
  end

  def get_objects
    eager_loading = @resource.reflect_on_all_associations(:belongs_to).reject { |i| i.options[:polymorphic] }.map { |i| i.name }

    @resource.build_conditions(params).each do |condition|
      @resource = @resource.where(condition)
    end

    @resource.build_joins(params).each do |join|
      @resource = @resource.joins(join)
    end

    if @resource.typus_options_for(:only_user_items)
      check_resources_ownership
    end

    @items = @resource.order(set_order).includes(eager_loading)
  end

  def set_fields
    @fields = @resource.typus_fields_for(params[:action].action_mapper)
  end

  def set_order
    params[:sort_order] ||= "desc"
    params[:order_by] ? "#{@resource.table_name}.#{params[:order_by]} #{params[:sort_order]}" : @resource.typus_order_by
  end

  def redirect_on_success
    action = @resource.typus_options_for(:action_after_save)
    path = params.dup.cleanup
    path.merge!(:action => action)

    case params[:action]
    when "create"
      path.merge!(:id => @item.id) unless action.eql?("index")
      notice = Typus::I18n.t("%{model} successfully created.", :model => @resource.model_name.human)
    when "update", "detach"
      case action
      when "index"
        if params[:back_to]
          path = "#{params[:back_to]}##{@resource.to_resource}"
        else
          path.delete_if { |k, v| %w(action id).include?(k) }
        end
      else
        path.merge!(:action => action) #, :id => @item.id)
      end
      notice = Typus::I18n.t("%{model} successfully updated.", :model => @resource.model_name.human)
    end

    redirect_to path, :notice => notice
  end

  ##
  # Here what we basically do is to associate objects after they have been
  # created. It's similar to calling `relate`.
  #
  # We have two objects:
  #
  #   - @item: Which is the create object.
  #   - item: Which is the object which be associated to.
  #
  # http://0.0.0.0:3000/admin/entries/new?back_to=%2Fadmin%2Fcategories%2Fedit%2F3&resource=categories&resource_id=3
  #
  def create_with_back_to

    #
    # Find the remote object which is named item!
    #

    item_class = params[:resource].typus_constantize
    item = item_class.find(params[:resource_id]) if params[:resource_id]

    ##
    # Detect which kind of relationship there's between both models.
    #

    ##
    # Here we have something like:
    #
    # Eg 1.
    #
    #   - We are editing an Order and want to add a new Invoice.
    #   - Click on "Add New" and we are redirected to the form.
    #   - We want to know which kind of relationship there's between both
    #     objects.
    #
    #         >> Order.relationship_with(Invoice)
    #         => :has_one
    #
    # Eg 2.
    #
    #   - We are editing a Entry and want to add a new Attachment.
    #   - Click on "Add New" and we are redirected to the form.
    #   - We want to know which kind of relationship there's between both
    #     objects.
    #
    #         >> Entry.relationship_with(Attachment)
    #         => :has_and_belongs_to_many
    #
    # Eg 3.
    #
    #   - We are editing a Entry and want to add a new Comment.
    #   - Click on "Add New" and we are redirected to the form.
    #   - We want to know which kind of relationship there's between both
    #     objects.
    #
    #         >> Entry.relationship_with(Comment)
    #         => :has_many
    #
    # Eg 4.
    #
    #   - We are editing a Post (Entry) and want to add a new Attachment.
    #   - Click on "Add New" and we are redirected to the form.
    #   - We want to know which kind of relationship there's between both
    #     objects.
    #
    #         >> Post.relationship_with(Attachment)
    #         => :has_and_belongs_to_many
    #

    case item_class.relationship_with(@resource)
    when :has_one
      # Order#invoice = @item
      association_name = @resource.model_name.underscore.to_sym
      item.send("#{association_name}=", @item)
      worked = true
    when :has_and_belongs_to_many
      # Attachment#entries.push(item)
      association_name = @resource.model_name.tableize.to_sym
      worked = item.send(association_name).push(@item)
    when :belongs_to
      # Entry#comments.push(item)
      association_name = item_class.model_name.tableize.to_sym
      if item
        worked = @item.send(association_name).push(item)
      end
    end

    association = @resource.reflect_on_association(association_name)

    ##
    # Set @back_to
    #

    @back_to = if item
                 params[:back_to]
               else
                 "#{params[:back_to]}?#{association.primary_key_name}=#{@item.id}"
               end

    ##
    # Finally delete the associated object. Depending on your models setup
    # associated models will be removed or foreign_key will be set to nil.
    #

    if item
      if worked
        notice = Typus::I18n.t("%{model} successfully updated.", :model => item_class.model_name.human)
      else
        alert = @item.errors.full_messages
      end
    end

    redirect_to set_path, :notice => notice, :alert => alert
  end

  def default_action
    @resource.typus_options_for(:default_action_on_item)
  end

  ##
  # If we are trying to create a new Invoice which belongs_to Order, we should
  # verify before the the Order doesn't have an Invoice, otherwise we would
  # have and Order with many Invoices which is something not desired.
  #
  # Eg:
  #
  #     @resource (Invoice)
  #     params[:resource] = "Order"
  #     params[:resource_id] = "1"
  #
  # Does this Order already has an Invoice. If true, redirect to back.
  #
  def check_if_we_can_add_a_new_item
    if params[:resource] && params[:resource_id]
      item_class = params[:resource].typus_constantize
      item = item_class.find(params[:resource_id]) if params[:resource_id]

      if item_class.relationship_with(@resource) == :has_one
        association_name = @resource.model_name.underscore.to_sym
        if item.send(association_name)
          render :text => "Not allowed!", :status => :unprocessable_entity
        end
      end
    end
  end

end
