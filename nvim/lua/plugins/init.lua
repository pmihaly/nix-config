return {

  {
    'numToStr/Comment.nvim',
    config = true,
  },
  'tpope/vim-sleuth',
  {
    'ahmedkhalf/project.nvim',
    config = function() require("project_nvim").setup {} end
  },
  'Eandrju/cellular-automaton.nvim',
  {
    'kylechui/nvim-surround',
    config = true,
  },
  'wellle/targets.vim',
  {
    'windwp/nvim-autopairs',
    config = true,
  },
}
