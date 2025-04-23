/**
 * Atomic Momentum Icon Library
 * A curated collection of habit-specific SVG icons organized by category
 */

const IconLibrary = {
  // Health & Fitness category
  'health': {
    name: 'Health & Fitness',
    icons: {
      'workout': {
        name: 'Workout',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M6.5 14a1 1 0 1 0 0-2 1 1 0 0 0 0 2zm0 0V9m0 0a1 1 0 1 0 0-2 1 1 0 0 0 0 2zm11 5a1 1 0 1 0 0-2 1 1 0 0 0 0 2zm0 0V9m0 0a1 1 0 1 0 0-2 1 1 0 0 0 0 2zM6.5 7h11m-11 2h11m-11 3h11"></path></svg>'
      },
      'running': {
        name: 'Running',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M13 14.5c-1-1-2.5-2-2.5-2s-2 2-3 3c-.5.5-1.5.5-2.5-.5m10-7a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0zm-1 2.5-1.5 4.5 3 2m-4.5-4-1 2L8 10l1-3.5 2 .5-1 4"></path></svg>'
      },
      'yoga': {
        name: 'Yoga',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4a2 2 0 1 0 0 4 2 2 0 0 0 0-4zm-5 7.5 4-2.5m0 0 4 2.5M8 17l3-4.5m2 0L16 17m-4-4.5V7"></path></svg>'
      },
      'meditation': {
        name: 'Meditation',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M8 12c0-2.2 1.8-4 4-4s4 1.8 4 4M7 17c1.3-2 3-3 5-3s3.7 1 5 3M12 4v4"></path></svg>'
      },
      'water': {
        name: 'Hydration',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4c-4 4-6 7-6 10a6 6 0 0 0 12 0c0-3-2-6-6-10z"></path></svg>'
      },
      'healthy-meal': {
        name: 'Healthy Eating',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M3 14h18m-9-9v9m8 0a8 8 0 1 1-16 0m4-6c1 0 2 1 2 2m4-2c-1 0-2 1-2 2"></path></svg>'
      }
    }
  },
  
  // Productivity category
  'productivity': {
    name: 'Productivity',
    icons: {
      'reading': {
        name: 'Reading',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4h12a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zm0 2v12h12V6H6zm11 0v12M6 12h12"></path></svg>'
      },
      'writing': {
        name: 'Writing',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.85 2.85 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"></path></svg>'
      },
      'coding': {
        name: 'Coding',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4m6 0h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4m-3-4V4"></path></svg>'
      },
      'tasks': {
        name: 'Task List',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2M9 5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2m0 0v3M9 9l1 1 3-3"></path></svg>'
      },
      'planning': {
        name: 'Planning',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2z"></path></svg>'
      },
      'focus': {
        name: 'Deep Focus',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0M12 12m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0M12 7v5l2 2"></path></svg>'
      }
    }
  },
  
  // Mindfulness category
  'mindfulness': {
    name: 'Mindfulness',
    icons: {
      'self-care': {
        name: 'Self Care',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path></svg>'
      },
      'sleep': {
        name: 'Sleep',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M17 18a5 5 0 0 0-10 0M12 6a5 5 0 0 0 7 0M9 4v4h4"></path></svg>'
      },
      'music': {
        name: 'Music',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18V5l12-2v13M9 9l12-2M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0zm12-5a3 3 0 1 1-6 0 3 3 0 0 1 6 0z"></path></svg>'
      },
      'nature': {
        name: 'Nature',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M12 10v6m0 0a3 3 0 1 0 3 3V6a5 5 0 0 0-10 0v4a5 5 0 0 0 7 4.58"></path></svg>'
      },
      'outdoors': {
        name: 'Outdoors',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10zM12 1v2m0 18v2M4.22 4.22l1.42 1.42m12.72 12.72l1.42 1.42M1 12h2m18 0h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"></path></svg>'
      },
      'gratitude': {
        name: 'Gratitude',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M12 8a2 2 0 0 1 2 2c0 2-3 1.5-3 3m3 3v.01M12 3c7.2 0 9 1.8 9 9s-1.8 9-9 9-9-1.8-9-9 1.8-9 9-9z"></path></svg>'
      }
    }
  },
  
  // Learning category
  'learning': {
    name: 'Learning',
    icons: {
      'education': {
        name: 'Education',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2L2 6l10 4 10-4-10-4zM2 12l10 4 10-4M2 16l10 4 10-4"></path></svg>'
      },
      'brainstorm': {
        name: 'Brainstorming',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M9.663 17h4.673M12 12v3m3-8a4 4 0 0 1-8 0m2-2a4 4 0 1 0 4 0"></path></svg>'
      },
      'language': {
        name: 'Languages',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M3 5h12M9 3v2m1.048 14H10M3 7l2 5m0 0l1 2.5M5 12h3M12.751 5l2.842 9.948M16.5 17h-2.642m0 0L12.5 10.5"></path></svg>'
      },
      'science': {
        name: 'Research',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M6 18h8m-4-14v12m4-10a2 2 0 1 0 0-4 2 2 0 0 0 0 4z"></path></svg>'
      },
      'puzzle': {
        name: 'Problem Solving',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v2.5a2.5 2.5 0 0 1-2.5 2.5H7a2 2 0 1 0 0 4h2.5A2.5 2.5 0 0 1 12 15.5V18a2 2 0 1 1-4 0v-2m4-10h2.5A2.5 2.5 0 0 1 17 8.5V11a2 2 0 1 0 4 0V8.5A2.5 2.5 0 0 1 18.5 6H21a2 2 0 1 0 0-4h-2"></path></svg>'
      }
    }
  },
  
  // Finance category
  'finance': {
    name: 'Finance',
    icons: {
      'saving': {
        name: 'Saving',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M12 18v-2m0-8V6m0 6a2 2 0 1 0 0-4 2 2 0 0 0 0 4zm7 1c0 4.418-3.582 8-8 8s-8-3.582-8-8 3.582-8 8-8 8 3.582 8 8z"></path></svg>'
      },
      'investing': {
        name: 'Investing',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M16 6l-4 4-4-4-4 4m4 5v5m4-9v9m4-13v13"></path></svg>'
      },
      'budgeting': {
        name: 'Budgeting',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M9 7h6m-6 4h6m-6 4h6M5 22h14a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2z"></path></svg>'
      }
    }
  },
  
  // Social category
  'social': {
    name: 'Social',
    icons: {
      'call': {
        name: 'Phone Call',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"></path></svg>'
      },
      'messaging': {
        name: 'Messaging',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 0 1-9 9m9-9a9 9 0 0 0-9-9m9 9H3m9 9a9 9 0 0 1-9-9m9 9c1.66 0 3-8.04 3-9s-1.34-9-3-9m0 18c-1.66 0-3-8.04-3-9s1.34-9 3-9m-9 9a9 9 0 0 1 9-9"></path></svg>'
      },
      'meetup': {
        name: 'Meetup',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8h1a4 4 0 0 1 0 8h-1m-4-8v8m0-8a4 4 0 1 0-8 0v8a4 4 0 1 0 8 0V8z"></path></svg>'
      },
      'volunteering': {
        name: 'Volunteering',
        svg: '<svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M16 3.13a4 4 0 0 1 0 7.75M21 12c0 4.42-4 8-9 8s-9-3.58-9-8a7 7 0 0 1 13.95-1M15 13a2 2 0 1 0 0-4 2 2 0 0 0 0 4zm-8 1a1 1 0 1 0 0-2 1 1 0 0 0 0 2zm8.5 4.5a5 5 0 0 1-9 0"></path></svg>'
      }
    }
  }
};

export default IconLibrary; 