/*
  Store elements to Numo::<%=class_name%> from other.
  @overload store(other)
  @param [Object] other
  @return [Numo::<%=class_name%>] self
*/
static VALUE
<%=c_func%>(VALUE self, VALUE obj)
{
    VALUE r;

    <% Store.definitions.each do |x| %>
    if (<%=x.condition%>) {
        <%=x.c_func%>(self,obj);
        return self;
    }
    <% end %>

    if (IsNArray(obj)) {
        r = rb_funcall(obj, rb_intern("coerce_cast"), 1, cT);
        if (CLASS_OF(r)==cT) {
            <%=c_func%>(self,r);
            return self;
        }
    }

    <% if is_object %>
    numo_robject_store_numeric(self,obj);
    <% else %>
    rb_raise(nary_eCastError, "unknown conversion from %s to %s",
             rb_class2name(CLASS_OF(obj)),
             rb_class2name(CLASS_OF(self)));
    <% end %>
    return self;
}
