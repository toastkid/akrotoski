Thoth.Admin = Thoth.Admin || {};

Thoth.Admin.TagComplete = function () {
  // Shorthand.
  var d   = document,
      Y   = YAHOO,
      yut = Y.util,
      yuc = yut.Connect,
      yud = yut.Dom,
      yue = yut.Event;

  // -- Private Variables ------------------------------------------------------
  var cache = {},
      conn,
      data;

  // -- Private Methods --------------------------------------------------------

  /**
   * Gets the last tag in the specified input element, or <i>null</i> if there
   * are no tags.
   *
   * @method getLastTag
   * @param {HTMLElement|String} el input element
   * @return {String|null} last tag or <i>null</i> if there are no tags
   * @private
   */
  function getLastTag(el) {
    if (tag = getTags(el).pop()) {
      return tag;
    }

    return null;
  }

  /**
   * Returns a reference to the suggestion list element associated with the
   * specified tag input element. If the specified element is a suggestion list
   * element, it will be returned.
   *
   * @method getSuggestEl
   * @param {HTMLElement|String} el input element
   * @return {HTMLElement} suggestion list element or <i>null</i> if not found
   * @private
   */
  function getSuggestEl(el) {
    el = yud.get(el);

    if (yud.hasClass(el, 'suggested-tags')) {
      return el;
    }

    return yud.getNextSiblingBy(el, function (node) {
      return yud.hasClass(node, 'suggested-tags');
    });
  }

  /**
   * Parses a comma-separated list of tags in the specified input element and
   * returns it as an Array.
   *
   * @method getTags
   * @param {HTMLElement|String} el tag input element
   * @return {Array} tags
   * @private
   */
  function getTags(el) {
    var value = (el = yud.get(el)) ? el.value : null;

    if (value && value.length) {
      return value.split(/,\s*/);
    }

    return [];
  }

  /**
   * Replaces the last tag in the specified tag input element with the specified
   * tag.
   *
   * @method replaceLastTag
   * @param {HTMLElement|String} el tag input element
   * @param {String} tag tag text
   * @private
   */
  function replaceLastTag(el, tag) {
    var tags = getTags(el = yud.get(el));

    tags.pop()
    tags.push(tag);

    el.value = tags.join(', ');
  }

  /**
   * Sends an Ajax request for tags matching the specified query.
   *
   * @method requestTags
   * @param {HTMLElement} el input element that triggered the request
   * @param {String} query query string
   * @param {Number} (optional) limit maximum number of tags to return
   * @private
   */
  function requestTags(el, query, limit) {
    if (conn && yuc.isCallInProgress(conn)) {
      yuc.abort(conn);
    }

    var url = '/api/tag/suggest?q=' + encodeURIComponent(query);

    if (limit) {
      url += '&limit=' + encodeURIComponent(limit);
    }

    if (cache[url]) {
      handleResponse(cache[url]);
      return;
    }

    conn = yuc.asyncRequest('GET', url, {
      argument: [url, el],
      success : handleResponse,
      timeout : 1000
    });
  }

  // -- Private Event Handlers -------------------------------------------------

  /**
   * Handles keydown events on tag input fields.
   *
   * @method handleKeyDown
   * @param {Event} e event object
   * @private
   */
  function handleKeyDown(e) {
    var charCode = yue.getCharCode(e),
        el       = yue.getTarget(e),
        suggestEl;

    // Autocomplete the current tag when the tab key is pressed.
    if (charCode === 9 && !e.shiftKey && !e.ctrlKey && !e.altKey &&
          !e.metaKey && data.length && this.isVisible(el)) {
      yue.preventDefault(e);
      replaceLastTag(el, data[0][0]);
      this.hide(el);
    }
  }

  /**
   * Handles keyup events on tag input fields.
   *
   * @method handleKeyUp
   * @param {Event} e event object
   * @private
   */
  function handleKeyUp(e) {
    var charCode = yue.getCharCode(e),
        el       = yue.getTarget(e),
        tag;

    if (charCode < 46 && charCode !== 8 && charCode !== 32) {
      return;
    }

    tag = getLastTag(el);

    if (tag) {
      requestTags(el, tag);
    } else {
      this.hide(el);
    }
  }

  /**
   * Handles Ajax responses.
   *
   * @method handleResponse
   * @param {Object} response response object
   * @private
   */
  function handleResponse(response) {
    if (!cache[response.argument[0]]) {
      cache[response.argument[0]] = response;
    }

    try {
      data = Y.lang.JSON.parse(response.responseText);
      Thoth.Admin.TagComplete.refresh(response.argument[1], data);
    } catch (e) {}
  }

  /**
   * Handles clicks on the tag suggestions.
   *
   * @method handleTagClick
   * @param {Event} e event object
   * @param {HTMLElement} el tag input element
   * @private
   */
  function handleTagClick(e, el) {
    var a = yue.getTarget(e);

    if (a.tagName.toLowerCase() !== 'a') {
      return;
    }

    yue.preventDefault(e);
    replaceLastTag(el, a.getAttribute('tagText'));
    el.focus();

    Thoth.Admin.TagComplete.hide(el);
  }

  return {
    // -- Public Methods -------------------------------------------------------

    /**
     * Initializes the TagComplete module on this page.
     *
     * @method init
     */
    init: function () {
      var self = this,
          list;

      yud.getElementsByClassName('tags-input', 'input', 'doc', function (el) {
        // Listen for keys on tag input fields.
        yue.on(el, 'keydown', handleKeyDown, self, true);
        yue.on(el, 'keyup', handleKeyUp, self, true);

        // Turn off browser autocomplete to avoid excess annoyingness.
        el.setAttribute('autocomplete', 'off');

        // Create a suggestion list element under the input element.
        list = d.createElement('ol');
        list.className = 'suggested-tags hidden';

        yud.insertAfter(list, el);
        yue.on(list, 'click', handleTagClick, el);
      });
    },

    /**
     * Clears the suggestions for the specified element.
     *
     * @method clear
     * @param {HTMLElement|String} el input element or suggestion list
     */
    clear: function (el) {
      if (el = getSuggestEl(el)) {
        el.innerHTML = '';
      }
    },

    /**
     * Hides the suggestions for the specified element.
     *
     * @method hide
     * @param {HTMLElement|String} el input element or suggestion list
     */
    hide: function (el) {
      if (el = getSuggestEl(el)) {
        yud.addClass(el, 'hidden');
      }
    },

    /**
     * Returns <i>true</i> if suggestions for the specified element are visible,
     * <i>false</i> otherwise.
     *
     * @method isVisible
     * @param {HTMLElement|String} el input element or suggestion list
     * @return <i>true</i> if suggestions are visible, <i>false</i> otherwise
     */
    isVisible: function (el) {
      return !yud.hasClass(getSuggestEl(el), 'hidden');
    },

    /**
     * Refreshes the tag suggestions for the specified element.
     *
     * @method refresh
     * @param {HTMLElement|String} el input element or suggestion list
     * @param {Array} (optional) tags suggested tags
     */
    refresh: function (el, tags) {
      var a, i, li, tag;

      if (!(el = getSuggestEl(el))) {
        return;
      }

      this.clear(el);

      if (!tags || tags.length === 0) {
        this.hide(el);
        return;
      }

      for (i = 0; i < tags.length; ++i) {
        tag = tags[i];
        li  = d.createElement('li');
        a   = d.createElement('a');

        a.href = '#';
        a.appendChild(d.createTextNode(tag[0] + ' (' + tag[1] + ')'));
        a.setAttribute('tagText', tag[0]);

        li.appendChild(a);
        el.appendChild(li);
      }

      this.show(el);
    },

    /**
     * Shows the suggestions for the specified element.
     *
     * @method show
     * @param {HTMLElement|String} el input element or suggestion list
     */
    show: function (el) {
      if (el = getSuggestEl(el)) {
        yud.removeClass(el, 'hidden');
      }
    }
  };
}();

YAHOO.util.Event.onDOMReady(Thoth.Admin.TagComplete.init,
    Thoth.Admin.TagComplete, true);
