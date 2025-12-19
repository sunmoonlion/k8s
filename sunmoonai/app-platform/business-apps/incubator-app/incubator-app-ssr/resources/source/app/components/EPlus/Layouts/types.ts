import type { TabsProps, TabsPaneContext } from 'element-plus'
import type { LocaleItem } from '../Themes/types'
import type { AvatarMenuProps } from '../Avatar/types'
import type { ThemeSettingsProps } from '../Themes/types'
import type { AppRouteMenuItem } from '../Menu/types'
import { TabActions } from './const'

export interface HeaderProps extends Partial<AvatarMenuProps> {
  collapse: boolean
  showCollapse?: boolean
  // availableLocales: string[]
  locales: LocaleItem[]
  settings?: ThemeSettingsProps
}

export interface HeaderTabsProps extends Partial<TabsProps> {
  data: AppRouteMenuItem[]
}

export type TabPaneName = string | number

export type HeaderTabsEvents = {
  tabClick: [pane: TabsPaneContext, ev: Event]
  tabChange: [name: TabPaneName]
  edit: [paneName: TabPaneName | undefined, action: 'remove' | 'add']
  tabRemove: [name: TabPaneName]
  tabAdd: []
  tabMenuClick: [action: TabActions]
}
