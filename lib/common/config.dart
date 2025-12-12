// ignore_for_file: constant_identifier_names, non_constant_identifier_names

const CARD_CHAR_LIMIT = 65536;
const PAGE_CHAR_LIMIT = 1048576;
const CARD_STRING_LIMIT = 1024;
const PAGE_STRING_LIMIT = 2048;

const TEST_FEATURES = bool.fromEnvironment("TEST_FEATURES");

const BUILD_DATE = String.fromEnvironment(
  "BUILD_DATE",
  defaultValue: "00unknown",
);
const VERSION_NAME = String.fromEnvironment(
  "VERSION_NAME",
  defaultValue: "_unknown",
);

const CONTACT = String.fromEnvironment("CONTACT");
const HELP_LINK = String.fromEnvironment("HELP_LINK");
const NEWS_LINK = String.fromEnvironment("NEWS_LINK");
const VERSION_LINK = String.fromEnvironment("VERSION_LINK");
