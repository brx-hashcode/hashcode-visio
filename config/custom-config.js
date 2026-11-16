// Captions in French unless the page embedding the call names another
// language (configOverwrite.transcription.preferredLanguage: French or
// English are the ones Rabotka sends). The captions are what is said, not a
// translation: no « translate into » languages are offered.
// docker-jitsi-meet appends this file to config.js at start;
// docker-compose.yml mounts it at /config/custom-config.js.
config.transcription.translationEnabled = false;
config.transcription.useAppLanguage = false;
config.transcription.preferredLanguage = 'fr-FR';

// Ended for everyone (« Terminer », or a moderator's « End meeting for all »):
// no « L'appel a été terminé » box waiting for an « Ok ». The call hangs up
// and tells the page embedding it at once (readyToClose), which closes it.
config.notifyOnConferenceDestruction = false;

// Leaving a call (« Quitter »): straight to our close page (config/web/
// close.html) as soon as the room is left, ~0.3 s. Without it, Jitsi shows
// « Merci d'avoir utilisé… » and waits 3 s before going back to the welcome page.
config.enableClosePage = true;
