class ScraperScripts {
  /// JavaScript to identify the scrollable results container and scroll it down.
  static const String autoScroll = """
    (function() {
      // Common selectors for the Google Maps results feed container
      const feedSelectors = [
        'div[role="feed"]',
        '.m67H60',
        '.section-layout.section-scrollbox',
        'div[jsaction*="scroll"]'
      ];
      
      let feed = null;
      for (const selector of feedSelectors) {
        feed = document.querySelector(selector);
        if (feed && feed.scrollHeight > feed.clientHeight) break;
      }

      if (feed) {
        // Random scroll amount to mimic human behavior
        const scrollAmount = Math.floor(Math.random() * 300) + 400;
        feed.scrollBy(0, scrollAmount);
        return {
          success: true,
          scrollTop: feed.scrollTop,
          scrollHeight: feed.scrollHeight,
          clientHeight: feed.clientHeight,
          atBottom: (feed.scrollTop + feed.clientHeight) >= (feed.scrollHeight - 10)
        };
      }
      return { success: false, error: 'Feed container not found' };
    })();
  """;

  /// JavaScript to check if the "At the end of the list" message is visible.
  static const String checkEndReached = """
    (function() {
      const endMessage = document.querySelector('.HlvSq');
      if (endMessage && endMessage.innerText.includes('reached the end')) {
        return true;
      }
      // Check for common 'no more results' indicators
      return document.body.innerText.includes('reached the end of the list') ||
             document.body.innerText.includes('No more results');
    })();
  """;

  /// JavaScript to extract basic data from the currently visible listing cards.
  static const String extractListings = """
    (function() {
      // Targets the business cards in the results list
      const cardSelectors = [
        'div[jsaction*="dg.card"]',
        '.nv2PK',
        '.VkpS9b'
      ];

      let cards = [];
      for (const selector of cardSelectors) {
        const found = document.querySelectorAll(selector);
        if (found.length > 0) {
          cards = Array.from(found);
          break;
        }
      }

      return cards.map(card => {
        // Inner selectors often change, so we try multiple common ones
        const name = card.querySelector('.qBF1Pd, .fontHeadlineSmall, .lrz7Ub')?.innerText || '';
        const rating = card.querySelector('.MW4T7d, .Z4Crt')?.innerText || '';
        const reviews = card.querySelector('.UY7F9, .R66be')?.innerText?.replace(/[()]/g, '') || '';
        
        // Multi-line info container
        const infoLines = card.querySelectorAll('.W4Efsd');
        let category = '';
        let address = '';
        
        if (infoLines.length > 0) {
            const firstLine = infoLines[0].innerText.split('·');
            category = firstLine[0]?.trim() || '';
        }
        
        // Coordinates can often be found in the link
        const link = card.querySelector('a')?.href || '';
        
        return {
          name: name.trim(),
          rating: rating.trim(),
          reviews: reviews.trim(),
          category: category.trim(),
          link: link,
          id: btoa(name + category).substring(0, 16) // Simple unique ID
        };
      });
    })();
  """;
}
