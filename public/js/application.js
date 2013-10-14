$(document).ready(function(){
  //apply autofold
  $(".autofold").each(function(i){ autoFold(this)});
  if($('#tag-tree').size() > 0){
    initHomepageEditor();
  }
});

function initHomepageEditor(){
  $('#tag-tree').nestedSortable({
    handle: 'div',
    items: "li:not(.undraggable)",
    toleranceElement: '> div',
    placeholder: "sortable-placeholder"
  });
  $('.colorpicker-input').ColorPicker({
    onSubmit: function(hsb, hex, rgb, el) {
      var newColor = ("#"+hex);
      console.log("newColor = "+newColor+", $(el).attr('class') = "+$(el).attr('class'));
      $(el).val(newColor);
      $(el).css("background",newColor);
      $(el).ColorPickerHide();
    }
  });
}

function submitUpdateTagsForm(){
  //set parent_id to "" in all the tags in the NOT USED list
  $("#other-tags").find(".parent-id-field, .position-field").val('');
  //set parent id and position in all the tags in the NAVBAR list
  $(".navbar-tags .tag-li").each(function(i,childLi){
    childLi = $(childLi);
    childLi.find(".parent-id-field").eq(0).val(childLi.parents(".tag-li").eq(0).attr("id").replace("tag-",""));
    childLi.find(".position-field").eq(0).val(childLi.index() + 1);
  });
  $("#update-tags-submit").click();
}


//wrap container around all content after 1st para, hide container, add "More" link before it, and make "More" toggleSlide the container
function autoFold(el){
  var element = $(el);
  var html = element.html().split(/\<\!\-\-\s?fold\s?\-\-\>/);
  if(html.length > 1){
    element.html(html[0] + 
            "<p><a class=\"moreLink\" href=\"#\">More...</a></p>" + 
            "<div class='fold-container hidden'>" +
            html[1] + 
            "</div>");
    var moreLink = element.find(".moreLink").eq(0);
    moreLink.click(function(ev){
      moreLink.parent().siblings('.fold-container').slideToggle();
      moreLink.parent().hide();    
      ev.preventDefault();
      ev.stopPropagation();    
    });
  } 
}


