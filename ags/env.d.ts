declare module "*.scss" {
  const content: string;
  export default content;
}

declare module "fuzzysort/fuzzysort.js" {
  import fuzzysort from "fuzzysort";
  export default fuzzysort;
}
