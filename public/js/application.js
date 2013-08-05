$(document).ready(function(){
  //apply autofold
  $(".autofold").each(function(i){ autoFold(this)});
});

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
